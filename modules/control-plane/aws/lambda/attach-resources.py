"""
Lambda function to attach EBS volumes to control plane instances during ASG lifecycle events.

This function is triggered by ASG lifecycle hooks via EventBridge when a new control plane
instance is launched. It:
1. Identifies the slot/node index from the ASG name
2. Finds the corresponding EBS volume by tag
3. Attaches the volume to the instance
4. Completes the lifecycle hook to allow the instance to continue booting

Environment Variables:
    CLUSTER_NAME: Name of the Talos cluster
    MAX_RETRY_ATTEMPTS: Maximum number of retry attempts for volume attachment
    RETRY_DELAY_BASE: Base delay in seconds for exponential backoff
"""

import json
import logging
import os
import re
import time
from typing import Optional

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")
autoscaling = boto3.client("autoscaling")

CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "")
MAX_RETRY_ATTEMPTS = int(os.environ.get("MAX_RETRY_ATTEMPTS", "5"))
RETRY_DELAY_BASE = int(os.environ.get("RETRY_DELAY_BASE", "2"))


def lambda_handler(event: dict, context) -> dict:
    """
    Main Lambda handler for ASG lifecycle events.

    Args:
        event: EventBridge event containing ASG lifecycle action details
        context: Lambda context object

    Returns:
        dict with statusCode and body
    """
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        detail = event.get("detail", {})
        lifecycle_hook_name = detail.get("LifecycleHookName")
        asg_name = detail.get("AutoScalingGroupName")
        instance_id = detail.get("EC2InstanceId")
        lifecycle_action_token = detail.get("LifecycleActionToken")

        if not all([lifecycle_hook_name, asg_name, instance_id]):
            raise ValueError(f"Missing required fields in event: {event}")

        logger.info(
            f"Processing lifecycle hook '{lifecycle_hook_name}' for instance "
            f"'{instance_id}' in ASG '{asg_name}'"
        )

        slot = extract_slot_from_asg_name(asg_name)
        if slot is None:
            raise ValueError(f"Could not extract slot from ASG name: {asg_name}")

        logger.info(f"Extracted slot: {slot}")

        volume_id = find_volume_for_slot(slot)
        if not volume_id:
            raise ValueError(f"Could not find EBS volume for slot {slot}")

        logger.info(f"Found volume: {volume_id}")

        wait_for_instance_running(instance_id)

        volume_success = attach_volume_with_retry(volume_id, instance_id)
        if not volume_success:
            logger.error(f"Failed to attach volume {volume_id} to {instance_id}")
            complete_lifecycle_action(
                asg_name,
                lifecycle_hook_name,
                instance_id,
                lifecycle_action_token,
                "ABANDON",
            )
            return {"statusCode": 500, "body": "Failed to attach volume"}

        logger.info(f"Successfully attached volume {volume_id} to {instance_id}")

        complete_lifecycle_action(
            asg_name,
            lifecycle_hook_name,
            instance_id,
            lifecycle_action_token,
            "CONTINUE",
        )
        return {"statusCode": 200, "body": "Volume attached successfully"}

    except Exception as e:
        logger.exception(f"Error processing event: {e}")

        try:
            if "detail" in event:
                detail = event["detail"]
                complete_lifecycle_action(
                    detail.get("AutoScalingGroupName"),
                    detail.get("LifecycleHookName"),
                    detail.get("EC2InstanceId"),
                    detail.get("LifecycleActionToken"),
                    "ABANDON",
                )
        except Exception as abandon_error:
            logger.error(f"Failed to abandon lifecycle action: {abandon_error}")

        raise


def extract_slot_from_asg_name(asg_name: str) -> Optional[int]:
    """
    Extract the slot number from ASG name.

    Expected format: "{cluster_name}-control-plane-{slot}"
    Example: "my-cluster-control-plane-2" -> 2

    Args:
        asg_name: Auto Scaling Group name

    Returns:
        Slot number as integer, or None if not found
    """
    match = re.search(r"-(\d+)$", asg_name)
    if match:
        return int(match.group(1))
    return None


def find_volume_for_slot(slot: int) -> Optional[str]:
    """
    Find the EBS volume ID for the given slot.

    Searches for volumes with tags:
    - Cluster = "{cluster_name}"
    - Slot = "{slot}"
    - VolumeType = "ephemeral"

    Args:
        slot: Control plane slot number

    Returns:
        Volume ID if found, None otherwise
    """
    try:
        response = ec2.describe_volumes(
            Filters=[
                {"Name": "tag:Cluster", "Values": [CLUSTER_NAME]},
                {"Name": "tag:Slot", "Values": [str(slot)]},
                {"Name": "tag:VolumeType", "Values": ["ephemeral"]},
            ]
        )

        volumes = response.get("Volumes", [])
        if not volumes:
            logger.warning(f"No volume found for cluster '{CLUSTER_NAME}' slot {slot}")
            return None

        if len(volumes) > 1:
            logger.warning(f"Multiple volumes found for slot {slot}, using first one")

        return volumes[0]["VolumeId"]

    except ClientError as e:
        logger.error(f"Error finding volume: {e}")
        return None


def wait_for_instance_running(instance_id: str, timeout: int = 120) -> None:
    """
    Wait for instance to be in 'running' state.

    Args:
        instance_id: EC2 instance ID
        timeout: Maximum time to wait in seconds
    """
    logger.info(f"Waiting for instance {instance_id} to be running...")

    waiter = ec2.get_waiter("instance_running")
    waiter.wait(
        InstanceIds=[instance_id],
        WaiterConfig={"Delay": 5, "MaxAttempts": timeout // 5},
    )

    logger.info(f"Instance {instance_id} is now running")


def attach_volume_with_retry(volume_id: str, instance_id: str) -> bool:
    """
    Attach volume to instance with retry logic.

    Handles cases where:
    - Volume is still attached to old instance (detach first)
    - Volume is in wrong state (wait and retry)
    - Transient AWS API errors (exponential backoff)

    Args:
        volume_id: EBS volume ID
        instance_id: EC2 instance ID

    Returns:
        True if attachment succeeded, False otherwise
    """
    for attempt in range(MAX_RETRY_ATTEMPTS):
        try:
            volume_info = ec2.describe_volumes(VolumeIds=[volume_id])["Volumes"][0]
            volume_state = volume_info["State"]
            attachments = volume_info.get("Attachments", [])

            logger.info(
                f"Attempt {attempt + 1}/{MAX_RETRY_ATTEMPTS}: "
                f"Volume {volume_id} state: {volume_state}, attachments: {attachments}"
            )

            if attachments:
                current_instance = attachments[0].get("InstanceId")
                attachment_state = attachments[0].get("State")

                if current_instance == instance_id and attachment_state == "attached":
                    logger.info(f"Volume already attached to target instance")
                    return True

                if attachment_state in ["attached", "attaching"]:
                    logger.info(
                        f"Volume attached to {current_instance} ({attachment_state}), "
                        f"detaching..."
                    )
                    ec2.detach_volume(VolumeId=volume_id, Force=True)
                    wait_for_volume_available(volume_id)

            if volume_state != "available":
                wait_for_volume_available(volume_id)

            logger.info(f"Attaching volume {volume_id} to {instance_id}")
            ec2.attach_volume(
                Device="/dev/sdf",
                InstanceId=instance_id,
                VolumeId=volume_id,
            )

            waiter = ec2.get_waiter("volume_in_use")
            waiter.wait(
                VolumeIds=[volume_id],
                WaiterConfig={"Delay": 5, "MaxAttempts": 24},
            )

            logger.info(f"Volume {volume_id} successfully attached")
            return True

        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            error_message = e.response.get("Error", {}).get("Message", "")

            logger.warning(
                f"Attempt {attempt + 1} failed: {error_code} - {error_message}"
            )

            if error_code in ["InvalidVolume.NotFound", "InvalidInstanceID.NotFound"]:
                logger.error(f"Unrecoverable error: {error_code}")
                return False

            if attempt < MAX_RETRY_ATTEMPTS - 1:
                delay = RETRY_DELAY_BASE ** (attempt + 1)
                logger.info(f"Retrying in {delay} seconds...")
                time.sleep(delay)

        except Exception as e:
            logger.exception(f"Unexpected error on attempt {attempt + 1}: {e}")
            if attempt < MAX_RETRY_ATTEMPTS - 1:
                delay = RETRY_DELAY_BASE ** (attempt + 1)
                time.sleep(delay)

    return False


def wait_for_volume_available(volume_id: str, timeout: int = 120) -> None:
    """
    Wait for volume to be in 'available' state.

    Args:
        volume_id: EBS volume ID
        timeout: Maximum time to wait in seconds
    """
    logger.info(f"Waiting for volume {volume_id} to be available...")

    waiter = ec2.get_waiter("volume_available")
    waiter.wait(
        VolumeIds=[volume_id],
        WaiterConfig={"Delay": 5, "MaxAttempts": timeout // 5},
    )

    logger.info(f"Volume {volume_id} is now available")


def complete_lifecycle_action(
    asg_name: str,
    hook_name: str,
    instance_id: str,
    token: str,
    result: str,
) -> None:
    """
    Complete the ASG lifecycle action.

    Args:
        asg_name: Auto Scaling Group name
        hook_name: Lifecycle hook name
        instance_id: EC2 instance ID
        token: Lifecycle action token
        result: "CONTINUE" to proceed, "ABANDON" to terminate instance
    """
    logger.info(f"Completing lifecycle action for {instance_id} with result: {result}")

    try:
        autoscaling.complete_lifecycle_action(
            LifecycleHookName=hook_name,
            AutoScalingGroupName=asg_name,
            LifecycleActionToken=token,
            LifecycleActionResult=result,
            InstanceId=instance_id,
        )
        logger.info(f"Lifecycle action completed successfully")
    except ClientError as e:
        logger.error(f"Failed to complete lifecycle action: {e}")
        raise
