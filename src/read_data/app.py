import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """Process a single item from the Map iterator.

    Expected input (from Step Functions Map ItemProcessor):
    {
        "in": {...},              # the item from the JSONL file
        "state_context": {...},   # shared context passed through the workflow
        "execution": {},          # execution metadata
        "page_token": <str|null>  # pagination token for continuation
    }

    Returns:
    {
        "in": {...},              # the original item
        "state_context": {...},   # preserved context
        "execution": {
            "execution-status": "finished"|"continue"|"abort"
        },
        "page_token": <str|null>  # next page token, null when done
    }
    """
    item = event.get("in", {})
    state_context = event.get("state_context", {})
    execution = event.get("execution", {})
    page_token = event.get("page_token", None)

    logger.info("Processing item=%s, page_token=%s", item, page_token)
    logger.info("TenantId=%s, ecaId=%s", item.get("tenant_id","unknown"), item.get("eca_id","unknown"))
   
    try:
        result, next_page_token = _process_item(item, page_token)

        has_more = next_page_token is not None
        status = "continue" if has_more else "finished"

        logger.info("Processed item=%s, next_page_token=%s, status=%s", item, next_page_token, status)
        return {
            "in": item,
            "state_context": state_context,
            "execution": {"execution-status": status},
            "page_token": next_page_token,
        }

    except Exception as e:
        logger.exception("Error processing item: %s", e)
        return {
            "in": item,
            "state_context": state_context,
            "execution": {"execution-status": "abort", "error": str(e)},
            "page_token": page_token,
        }

def _process_item(item, page_token):
    """Stub – replace with real processing logic.

    Args:
        item: The data item from the JSONL file.
        page_token: Pagination token for continuation (None on first call).

    Returns:
        (result, next_page_token) where next_page_token is None when done.
    """
    # TODO: implement actual data migration logic
    logger.info("Stub processing item=%s with page_token=%s", item, page_token)
    result = {"status": "ok"}
    next_page_token = 2 if page_token is None else None if page_token >= 3 else page_token + 1
    return result, next_page_token
    
