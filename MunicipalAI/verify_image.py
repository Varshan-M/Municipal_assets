# Business logic for mapping model predictions to asset/problem verification

# Configurable threshold
ACCEPT_THRESHOLD = 0.80

def verify_image_logic(selected_asset: str, selected_problem: str, detected_class: str, confidence: float) -> dict:
    """
    Verifies if the detected class matches the user's selected asset and problem.
    """
    selected_asset = selected_asset.lower()
    selected_problem = selected_problem.lower()
    
    # Mapping for Asset Verification (Model A - when it exists)
    # and Problem Verification (Model B)
    # This logic combines them based on the unified class list.
    
    is_valid = False
    
    if confidence < ACCEPT_THRESHOLD:
        return {
            "valid": False,
            "status": "low_confidence",
            "confidence": round(confidence, 4),
            "message": f"The image could not be verified confidently (threshold {ACCEPT_THRESHOLD}). Please upload a clearer image."
        }

    # Define matching logic
    if selected_asset == "road":
        if detected_class == "pothole":
            is_valid = True
    elif selected_asset == "public building":
        if detected_class in ["building_crack", "public_building_normal"]:
            is_valid = True
    elif selected_asset == "garbage bin":
        if detected_class == "trash_bin":
            is_valid = True
    elif selected_asset == "street light":
        if detected_class in ["street_light_working", "street_light_not_working"]:
            is_valid = True

    if is_valid:
        return {
            "valid": True,
            "status": "verified",
            "selected_asset": selected_asset,
            "selected_problem": selected_problem,
            "detected_class": detected_class,
            "confidence": round(confidence, 4),
            "message": "Image verified successfully."
        }
    else:
        return {
            "valid": False,
            "status": "asset_mismatch",
            "selected_asset": selected_asset,
            "selected_problem": selected_problem,
            "detected_class": detected_class,
            "confidence": round(confidence, 4),
            "message": f"Please upload the {selected_asset} image."
        }

def verify_resolution_logic(selected_asset: str, detected_class: str, confidence: float) -> dict:
    """
    Verifies if the uploaded image matches the 'repaired' state of the specified asset.
    """
    selected_asset = selected_asset.lower()
    
    is_valid = False
    expected_class = "Unknown"
    
    if confidence < ACCEPT_THRESHOLD:
        return {
            "valid": False,
            "status": "low_confidence",
            "confidence": round(confidence, 4),
            "message": f"The image could not be verified confidently (threshold {ACCEPT_THRESHOLD}). Please upload a clearer image of the repair."
        }

    # Strict mapping for Resolution Verification
    if selected_asset == "road":
        expected_class = "normal_road"
        if detected_class == "normal_road":
            is_valid = True
    elif selected_asset == "public building":
        expected_class = "public_building_normal"
        if detected_class == "public_building_normal":
            is_valid = True
    elif selected_asset == "garbage bin":
        expected_class = "trash_bin"
        if detected_class == "trash_bin":
            is_valid = True
    elif selected_asset == "street light":
        expected_class = "street_light_working"
        if detected_class == "street_light_working":
            is_valid = True

    if is_valid:
        return {
            "valid": True,
            "status": "verified",
            "selected_asset": selected_asset,
            "detected_class": detected_class,
            "confidence": round(confidence, 4),
            "message": "Resolution image verified successfully."
        }
    else:
        return {
            "valid": False,
            "status": "asset_mismatch",
            "selected_asset": selected_asset,
            "detected_class": detected_class,
            "confidence": round(confidence, 4),
            "message": f"Verification failed. The image appears to be a '{detected_class}' but we need visual proof of a '{expected_class}' to mark this as resolved."
        }
