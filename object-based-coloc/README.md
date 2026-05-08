# Object-Based Colocalization Analyzer

**Version 2.0 · Münster Imaging Network**  
A Fiji/ImageJ macro for **2D object-based** two-channel colocalization analysis.  
Supports both single image and batch processing.

---

## Requirements

- [Fiji](https://fiji.sc/) (ImageJ distribution)
- Two-channel fluorescence images (CZI, TIF, LIF or similar)

---

## Installation

**Option A – Drag & Drop**
1. Download [MIN_object-based-coloc_v1-0.ijm](MIN_object-based-coloc_v1-0.ijm)
3. Drag and drop the file into the Fiji window and click **Run**

**Option B – Menu**
1. In Fiji: **Plugins › Macros › Install...** and select the file

**Option C – Permanent installation**
1. Copy `coloc_macro.ijm` to your Fiji `plugins/` folder  
   (e.g. `Fiji.app/plugins/`)
2. Restart Fiji – the macro will appear under **Plugins** in the menu bar

---

## Step-by-Step Guide

### Step 1 – Mode & Settings

Choose between **Single Image** or **Batch** processing.  
Optionally load a `_Settings.txt` file from a previous run to pre-fill all parameters.

![Step 1 Screenshot](docs/screenshots/step1_mode.png)

---

### Step 2 – Output Folder

Select the folder where all result files will be saved.

---

### Step 3 – Image Restoration (Filters)

Select which pre-processing filters to apply before thresholding.  
Filters are applied to working copies only – originals are never modified.

| Filter | Purpose |
|---|---|
| Rolling Ball | Background subtraction |
| Top-Hat | Highlights small bright structures |
| Median | Noise reduction |
| Gaussian Blur | Smoothing |

![Step 3 Screenshot](docs/screenshots/step2_filters.png)

---

### Step 4 – Threshold & Particle Settings

Set the **threshold method** independently for each channel.  
In Single mode, **Manual (interactive)** thresholding is also available.

Define the **particle size range** (min/max area in px²) and whether objects touching the image edges should be excluded.

![Step 4 Screenshot](docs/screenshots/step3_threshold.png)

---

### Step 5 – Open Image (Single Mode only)

Select your image file. Multi-channel stacks are split automatically.  
For Z-stacks, choose a projection method (Max Intensity, Sum, Average, Median).

![Step 5 Screenshot](docs/screenshots/step4_open.png)

---

### Step 6 – Optional Manual Filtering

After automated filters are applied, the processed images are displayed.  
You can apply additional filters manually via the Fiji menus before continuing.

![Step 6 Screenshot](docs/screenshots/step5_manual_filter.png)

---

### Step 7 – Results

The macro generates the following output files per image:

| File | Content |
|---|---|
| `*_Mask_ChA.tif` | Binary mask – Channel A |
| `*_Mask_ChB.tif` | Binary mask – Channel B |
| `*_Mask_Coloc.tif` | Colocalization mask (AND of both channels) |
| `*_Coloc_ROIs.zip` | ROI set of all colocalized objects |
| `*_Results.csv` | Per-object measurements for both channels (measured on the **raw, unprocessed image** – filters do not affect intensity values) |
| `*_Settings.txt` | All parameters – reusable for batch runs |

In **Batch mode**, an additional `Batch_Summary.csv` is created with one row per image.

![Step 7 Screenshot](docs/screenshots/step6_results.png)

---

## Measurements per Object

For each colocalized object the following values are reported for both channels:

`Area · Mean Intensity · StdDev · Min · Max · IntDen`

---

## Tips

- Run in **Single mode** first to optimize filter and threshold settings, then use the saved `_Settings.txt` to run the same parameters on a whole folder in **Batch mode**
- If output files already exist, the macro will ask whether to **overwrite**, **rename** (with timestamp), or **cancel**

---

## Contact

**Münster Imaging Network**  
📧 microscopy@uni-muenster.de  
🌐 [uni.ms/imagingnetwork](https://uni.ms/imagingnetwork)

---

*No warranty provided. Interpretation of results is the responsibility of the researcher.*
