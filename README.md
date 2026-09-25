# Autonomous Municipal Asset Maintenance Operations AI

This project contains the backend AI image verification system for an autonomous municipal asset management platform. It verifies user-uploaded images against selected assets and problems (e.g., Road + Pothole).

## 1. Project Purpose
The goal is to develop a robust AI image-classification pipeline (using TensorFlow/Keras and MobileNetV2) that can verify whether a citizen-uploaded image matches the selected municipal asset/problem.

## 2. Dataset Structure
The required training dataset structure expects:
```
dataset/
├── train/
├── validation/
└── test/
```
Inside each of these, the following classes should exist:
- `pothole` (Positive examples of potholes)
- `building_crack` (Positive examples of damaged public buildings)
- `public_building_normal` (Negative examples of normal buildings)
- `trash_bin` (Positive examples of trash bins)
- `normal_road` (Negative examples of normal roads)
- `other` (Unrelated images to reject garbage inputs)

### Current Missing Data Status:
- **`normal_road`**: **MISSING**. Without this, the model cannot learn what a normal road looks like, making the "normal" class semantically ambiguous (it would only know about normal buildings).
- **`other`**: **MISSING**. Required to reject unrelated images (e.g., a picture of a dog).
- **`trash_bin`**: **INSUFFICIENT**. Only 12 images are currently available. Thousands are needed for a production model.

## 3. Dataset Preparation
To prepare the dataset from the raw sources, run:
```bash
python prepare_dataset.py
```
This script audits the data, subsamples large classes (like public buildings), and splits them into `train`, `validation`, and `test` directories while avoiding train/test leakage.

## 4. Installation
Install the dependencies using pip:
```bash
pip install -r requirements.txt
```

## 5. Training
Once the missing data (`normal_road`, `other`, `trash_bin`) is collected and placed into `D:\Municipal_assets\dataset`, re-run the preparation script and then start training:
```bash
python train_model.py
```
This trains a MobileNetV2 model using early stopping and learning rate reduction on plateau.

## 6. Evaluation
The `train_model.py` script automatically evaluates the model on the test set and generates:
- `results/classification_report.txt`
- `results/confusion_matrix.png`
- `results/training_history.png`
- `results/test_results.json`

## 7. Prediction
To test a single image from the command line:
```bash
python predict.py "path_to_image.jpg"
```

## 8. Verification
The `verify_image.py` module contains the business logic that maps model classifications to the application's Asset + Problem selections. 

## 9. FastAPI Startup
To start the backend server for the Flutter application:
```bash
cd api
uvicorn main:app --reload
```

## 10. Flutter Integration
The FastAPI server exposes a `POST /verify-image` endpoint. It expects `multipart/form-data`.

## 11. API Request Format
Fields:
- `asset`: (String) e.g., "road", "public_building"
- `problem`: (String) e.g., "pothole", "building_crack"
- `image`: (File) The uploaded image

## 12. API Response Format
```json
{
    "valid": true,
    "status": "verified",
    "selected_asset": "road",
    "selected_problem": "pothole",
    "detected_class": "pothole",
    "confidence": 0.9432,
    "message": "Image verified successfully."
}
```

## 13. Model Limitations
- The model relies heavily on the quality and diversity of the training data.
- The confidence threshold is currently set to `0.80`, but softmax confidence does not strictly prove an image is genuine. It should be tuned based on real-world validation.
- Missing `other` class images will cause the model to forcefully classify out-of-distribution images into one of the known classes.

## 14. Adding Additional Municipal Assets
1. Add the new images to the dataset source folder.
2. Update the classes list in `prepare_dataset.py`.
3. Re-run `prepare_dataset.py`.
4. Update the logic in `verify_image.py` to map the new classes.
5. Re-run `train_model.py`.

## 15. Retraining the Model
Simply re-run `python train_model.py` after adding new data. Ensure the dataset is prepared correctly first.
