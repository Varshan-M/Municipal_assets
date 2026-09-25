import os
import json
import matplotlib.pyplot as plt
from pathlib import Path
import tensorflow as tf
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import GlobalAveragePooling2D, Dropout, Dense
from tensorflow.keras.models import Sequential
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns
import numpy as np

# Configuration
DATASET_DIR = Path(r"D:\Municipal_assets\MunicipalAI\dataset")
MODELS_DIR = Path(r"D:\Municipal_assets\MunicipalAI\models")
RESULTS_DIR = Path(r"D:\Municipal_assets\MunicipalAI\results")

MODELS_DIR.mkdir(parents=True, exist_ok=True)
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

BATCH_SIZE = 32
IMG_SIZE = (224, 224)
INITIAL_EPOCHS = 15
FINE_TUNE_EPOCHS = 10
LEARNING_RATE = 1e-3

def build_model(num_classes):
    # Data Augmentation Layer
    data_augmentation = Sequential([
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.2),
        tf.keras.layers.RandomZoom(0.2),
        tf.keras.layers.RandomContrast(0.2),
    ], name="data_augmentation")

    # Base Model
    base_model = MobileNetV2(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False  # Freeze base model initially

    inputs = tf.keras.Input(shape=IMG_SIZE + (3,))
    x = data_augmentation(inputs)
    # MobileNetV2 expects inputs in [-1, 1], but tf.keras.utils.image_dataset_from_directory gives [0, 255]
    # We apply the specific preprocess_input function
    x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
    x = base_model(x, training=False)
    x = GlobalAveragePooling2D()(x)
    x = Dropout(0.2)(x)
    outputs = Dense(num_classes, activation='softmax')(x)

    model = tf.keras.Model(inputs, outputs)
    return model, base_model

def train():
    print("Loading datasets...")
    train_dataset = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR / 'train',
        shuffle=True,
        batch_size=BATCH_SIZE,
        image_size=IMG_SIZE
    )
    
    validation_dataset = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR / 'validation',
        shuffle=True,
        batch_size=BATCH_SIZE,
        image_size=IMG_SIZE
    )

    test_dataset = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR / 'test',
        shuffle=False,
        batch_size=BATCH_SIZE,
        image_size=IMG_SIZE
    )

    class_names = train_dataset.class_names
    num_classes = len(class_names)
    
    print(f"Found {num_classes} classes: {class_names}")
    
    # Save classes.json
    classes_dict = {str(i): name for i, name in enumerate(class_names)}
    with open(MODELS_DIR / 'classes.json', 'w') as f:
        json.dump(classes_dict, f, indent=4)
        
    model, base_model = build_model(num_classes)
    
    model.compile(
        optimizer=Adam(learning_rate=LEARNING_RATE),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy']
    )
    
    model_path = MODELS_DIR / 'municipal_asset_model.keras'
    
    callbacks = [
        EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=3, min_lr=1e-6),
        ModelCheckpoint(filepath=model_path, save_best_only=True, monitor='val_accuracy')
    ]
    
    print("Starting Phase 1: Training top layers...")
    history = model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=INITIAL_EPOCHS,
        callbacks=callbacks
    )
    
    print("Starting Phase 2: Fine-tuning...")
    base_model.trainable = True
    # Freeze bottom layers of MobileNetV2
    for layer in base_model.layers[:100]:
        layer.trainable = False
        
    model.compile(
        optimizer=Adam(learning_rate=LEARNING_RATE / 10),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=['accuracy']
    )
    
    history_fine = model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=FINE_TUNE_EPOCHS,
        callbacks=callbacks
    )
    
    evaluate_model(model, test_dataset, class_names, history, history_fine)

def evaluate_model(model, test_dataset, class_names, history, history_fine):
    print("Evaluating on test dataset...")
    loss, accuracy = model.evaluate(test_dataset)
    
    # Generate predictions
    y_true = []
    y_pred = []
    for images, labels in test_dataset:
        y_true.extend(labels.numpy())
        preds = model.predict(images, verbose=0)
        y_pred.extend(np.argmax(preds, axis=1))
        
    # Classification Report
    report = classification_report(y_true, y_pred, target_names=class_names, labels=range(len(class_names)), zero_division=0)
    with open(RESULTS_DIR / 'classification_report.txt', 'w') as f:
        f.write(report)
        
    # Test Results JSON
    test_results = {
        'test_loss': float(loss),
        'test_accuracy': float(accuracy)
    }
    with open(RESULTS_DIR / 'test_results.json', 'w') as f:
        json.dump(test_results, f, indent=4)
        
    # Confusion Matrix
    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=class_names, yticklabels=class_names)
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.title('Confusion Matrix')
    plt.tight_layout()
    plt.savefig(RESULTS_DIR / 'confusion_matrix.png')
    plt.close()
    
    # Training History
    acc = history.history['accuracy'] + history_fine.history['accuracy']
    val_acc = history.history['val_accuracy'] + history_fine.history['val_accuracy']
    plt.figure(figsize=(8, 6))
    plt.plot(acc, label='Training Accuracy')
    plt.plot(val_acc, label='Validation Accuracy')
    plt.legend(loc='lower right')
    plt.title('Training and Validation Accuracy')
    plt.savefig(RESULTS_DIR / 'training_history.png')
    plt.close()
    
    print("Evaluation complete. Results saved to results directory.")

if __name__ == "__main__":
    # GPU Check
    print("Num GPUs Available: ", len(tf.config.list_physical_devices('GPU')))
    train()
