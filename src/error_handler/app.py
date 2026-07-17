import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """Handle errors from the data migration step function.

    Expected input:
    {
        "in": {...},
        "backpack": {...},
        "execution": {
            "execution-status": "abort",
            ...
        }
    }
    """
    execution = event.get("execution", {})
    status = execution.get("execution-status", "abort")

    logger.error(
        "Migration error – status=%s, execution=%s",
        status,
        execution,
    )

    return {
        "error": True,
        "execution_status": status,
        "message": f"Migration aborted with status: {status}",
    }
