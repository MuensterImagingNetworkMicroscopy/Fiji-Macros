# Processing and Tile Stitching Macro
**Version 1.0 · Münster Imaging Network – Microscopy**

A Fiji/ImageJ macro for automated tile processing and stitching of multi-channel z-stack OME-TIFF acquisitions from Imspector (LVBT).

> Written by Sarah Weischer, Münster Imaging Network – Microscopy, 2026. AI-assisted: Claude (Anthropic).

---

## Requirements

- **[Fiji](https://fiji.sc/)** (ImageJ distribution)
- Imspector-exported OME-TIFF tiles with mosaic naming convention
- **Grid/Collection Stitching** plugin (bundled with Fiji by default)

---

## Filename Pattern

The macro expects filenames in the following structure:

```
18-07-29_20260505_21461_PMT - PMT [P_1] [XX x XX]_C00_xyz-Table Z0000.ome.tif
                                        └──────┘  └─┘            └──┘
                                       Mosaic pos  Ch           Z index
```

| Token | Example | Description |
|---|---|---|
| `[XX x XX]` | `[00 x 01]` | Mosaic tile position (grid X · Y) |
| `_C00` | `_C00`, `_C01` | Channel index (zero-based) |
| `Z0000` | `Z0000`–`Z0017` | Z-slice index (zero-based) |

---

## Installation

**Option A – Drag & Drop**
1. Download [`ProcessImspector_mosaic_v1.ijm`](ProcessImspector_mosaic_v1.ijm)
2. Drag and drop the file into the Fiji window and click **Run**

**Option B – Script Editor**
1. In Fiji: **File › New › Script...** or open an existing script
2. Paste or open the `.ijm` file and click **Run**

**Option C – Permanent Installation**
1. Copy `ProcessImspector_mosaic_v1.ijm` to your Fiji `plugins/` folder  
   (e.g. `Fiji.app/plugins/Macros/`)
2. Restart Fiji — the macro will appear under **Plugins › Macros** in the menu bar

---

## Step-by-Step Guide

### Step 1 – Input Parameters

When launched, a dialog prompts for all required settings:

| Parameter | Default | Description |
|---|---|---|
| `Input directory` | — | Folder containing the raw OME-TIFF tiles |
| `Output directory` | — | Folder where processed tiles and stitched result are saved |
| `File suffix` | `.ome.tif` | File extension filter |
| `Tile overlap` | `20` | Overlap in % used for stitching |
| `Channel names` | `DAPI, GFP` | Comma-separated names in acquisition order |
| `Pixel size (xy)` | `0.534` | Lateral pixel size in µm |
| `Pixel size (z)` | `3` | Axial voxel depth in µm |
| `Perform stitching?` | `true` | Check to run Grid/Collection Stitching after tile export |

---

### Step 2 – Automatic Detection

The macro scans the input folder and automatically detects:

- **Mosaic positions** — all unique `[XX x XX]` tags → defines the tile grid
- **Number of channels** — from the highest `_C` index found
- **Number of z-slices** — from the highest `Z` index found
- **Grid dimensions X · Y** — from the maximum tile coordinates

Detection results are printed to the Fiji Log window for verification.

---

### Step 3 – Tile Processing

For each unique mosaic position the macro:

1. Opens all matching files (all channels, all Z-slices) using `File.openSequence` with a position filter
2. Converts the flat stack to a **Hyperstack** with the correct `XYZCT` order
3. Sets pixel size (xy and z) and assigns channel names and labels
4. Saves the tile as a TIFF to a subfolder in the output directory

**Output filename pattern:**
```
<input_folder_name>/<input_folder_name>_XX_x_YY.tif
```

---

### Step 4 – Stitching (optional)

If **Perform stitching?** is checked, the macro calls the **Grid/Collection Stitching** plugin with:

- Filename-defined tile positions parsed from `{xx}` and `{yy}` placeholders
- Linear Blending fusion
- Overlap computation enabled
- Memory-saving computation mode

The final stitched image is saved as:
```
<output_directory>/<input_folder_name>_stitched.tif
```

> **Plugin reference:** Preibisch S., Saalfeld S. & Tomancak P. (2009). Globally optimal stitching of tiled 3D microscopic image acquisitions. *Bioinformatics*, 25(11), 1463–1465. https://doi.org/10.1093/bioinformatics/btp184

---

## Output Structure

```
Output directory/
├── <dataset_name>/
│   ├── <dataset_name>_00_x_00.tif      ← Tile [0,0] as Hyperstack
│   ├── <dataset_name>_01_x_00.tif      ← Tile [1,0] as Hyperstack
│   ├── <dataset_name>_00_x_01.tif      ← Tile [0,1] as Hyperstack
│   └── <dataset_name>_01_x_01.tif      ← Tile [1,1] as Hyperstack
├── <dataset_name>_stitched.tif         ← Final fused image
└── TileConfiguration.txt               ← Stitching coordinates (Fiji output)
```

---

## Notes & Tips

- Channel names must be entered **in acquisition order** (matching `C00`, `C01`, …). If fewer names than channels are provided, remaining channels are labelled `C0`, `C1`, etc.
- Tile overlap should match the value set during acquisition. If unknown, `10–20 %` is a safe starting point.
- The macro uses **backslash** as the path separator for Windows compatibility. On macOS/Linux, paths with forward slashes are handled automatically by Fiji.
- All open images are closed after saving to keep memory usage low during batch runs.
