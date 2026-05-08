// ====================================================================
// Macro: Object-Based Colocalization Analyzer
// Version: 2.0
// Author: Dr. Thomas Zobel – Münster Imaging Network
// Website: https://uni.ms/imagingnetwork
// Contact: microscopy@uni-muenster.de
//
// Description:
//   Professional two-channel, object-based colocalization workflow.
//   Supports Single Image and Batch (folder) processing.
//   After a single run, all settings are saved to a *_Settings.txt
//   file which can be loaded in batch mode to pre-fill all parameters.
//
// Output (per image):
//   *_Mask_ChA.tif       Binary mask – Channel A
//   *_Mask_ChB.tif       Binary mask – Channel B
//   *_Mask_Coloc.tif     Colocalization mask (binary AND)
//   *_Coloc_ROIs.zip     ROI set of colocalized objects
//   *_Results.csv        Per-object measurements (both channels)
// Additional batch output:
//   Batch_Summary.csv    One row per image with key statistics
//   Batch_Log.txt        Complete processing log
//   Batch_Settings.txt   Settings file for future batch runs
//
// DISCLAIMER: No warranty provided. Interpretation and measurement
// results are the responsibility of the researcher, not
// Münster Imaging Network.
// ====================================================================


// ── Global filter variables (used in applyFilters function) ──────────
var do_rb       = 0;   var rb_r     = 50;
var do_tophat   = 0;   var tophat_r = 5;
var do_median   = 0;   var med_r    = 2;
var do_gaussian = 0;   var gauss_s  = 1.0;

// ── Global processing settings (pre-filled from settings file) ────────
var g_thr1        = "RenyiEntropy";
var g_thr2        = "RenyiEntropy";
var g_min_area    = 5;
var g_max_area    = 10000;
var g_excl_edges  = 1;
var g_chA_num     = 1;
var g_chB_num     = 2;
var g_proj_method = "Max Intensity";
var g_suffix      = ".tif";

// ── Global result variables (set by processImage, read by batch loop) ─
var res_n_coloc    = 0;
var res_total_area = 0;
var res_avg_chA    = 0;
var res_avg_chB    = 0;


// ════════════════════════════════════════════════════════════════════
//  MAIN
// ════════════════════════════════════════════════════════════════════

// ─── Initialise ──────────────────────────────────────────────────────
print("\\Clear");
run("Clear Results");
roiManager("reset");
if (!isOpen("ROI Manager")) run("ROI Manager...");
setBackgroundColor(0, 0, 0);
setForegroundColor(255, 255, 255);

print("-----------------------------------------------");
print("   Object-Based Colocalization Analyzer  v1.0");
print("   Dr. Thomas Zobel · Münster Imaging Network");
print("   uni.ms/imagingnetwork");
print("-----------------------------------------------\n");


// ─── Step 1: Mode selection ───────────────────────────────────────────
mode_items = newArray("Single Image", "Batch (process entire folder)");
Dialog.create("Step 1 of 4  –  Mode & Settings");
Dialog.addMessage(
    "Object-Based Colocalization Analyzer\n" +
    "Münster Imaging Network  ·  uni.ms/imagingnetwork\n" +
    "-----------------------------------------------");
Dialog.addRadioButtonGroup("Processing mode:", mode_items, 2, 1, "Single Image");
Dialog.addMessage(" ");
Dialog.addCheckbox("Load settings from a previous run  (*_Settings.txt)", false);
Dialog.addMessage(
    "Settings files are saved automatically after each single run.\n" +
    "Loading a settings file pre-fills all filter and threshold values.");
Dialog.show();

mode_choice  = Dialog.getRadioButton();
load_sett    = Dialog.getCheckbox();
isBatch      = (mode_choice == "Batch (process entire folder)");

// ─── Load settings file (optional) ───────────────────────────────────
if (load_sett) {
    sett_path = File.openDialog("Select settings file  (*_Settings.txt)");
    if (sett_path != "" && sett_path != "null")
        loadSettings(sett_path);
    else
        print("No settings file selected - using defaults.");
}


// ─── Output folder ────────────────────────────────────────────────────
output_dir = getDirectory("Select output folder for all result files");
if (output_dir == "") exit("No output folder selected. Cancelled.");
if (!endsWith(output_dir, File.separator)) output_dir += File.separator;


// ─── If Batch: input folder & file suffix ────────────────────────────
if (isBatch) {
    input_dir = getDirectory("Select input folder containing image files");
    if (input_dir == "") exit("No input folder selected. Cancelled.");

    Dialog.create("Batch Input Settings");
    Dialog.addMessage(
        "Specify which files to process.\n" +
        "All matching files in the input folder will be analysed.");
    Dialog.addString("File suffix (e.g. .tif, .czi):", g_suffix);
    Dialog.addMessage(
        "Channel numbers are taken from loaded settings\n" +
        "or can be adjusted below:");
    Dialog.addNumber("Channel A number:", g_chA_num);
    Dialog.addNumber("Channel B number:", g_chB_num);
    Dialog.show();
    g_suffix  = Dialog.getString();
    g_chA_num = Dialog.getNumber();
    g_chB_num = Dialog.getNumber();

    print("Input folder  : " + input_dir);
    print("File suffix   : " + g_suffix);
    print("Channel A     : " + g_chA_num);
    print("Channel B     : " + g_chB_num + "\n");

    // Batch mode: manual threshold not supported
    if (g_thr1 == "Manual (interactive)") g_thr1 = "RenyiEntropy";
    if (g_thr2 == "Manual (interactive)") g_thr2 = "RenyiEntropy";
}


// ─── Step 2: Image Restoration ───────────────────────────────────────
Dialog.create("Step 2 of 4  –  Image Restoration");
Dialog.addMessage(
    "Select filters to apply before thresholding.\n" +
    "Applied to working copies only – originals are preserved.\n" +
    "Order: Rolling Ball > Top-Hat > Median > Gaussian.");
Dialog.addMessage("----  Background Subtraction  ----");
Dialog.addCheckbox("Rolling Ball Background Subtraction", do_rb);
Dialog.addNumber("  Radius (px):", rb_r);
Dialog.addMessage("----  Structure Enhancement  ----");
Dialog.addCheckbox("Top-Hat Filter  (highlights small bright structures)", do_tophat);
Dialog.addNumber("  Radius (px):", tophat_r);
Dialog.addMessage(
    "  White Top-Hat = Image - Morphological Opening\n" +
    "  Opening = Erosion (Min filter) + Dilation (Max filter)");
Dialog.addMessage("---- Noise Reduction  ----");
Dialog.addCheckbox("Median Filter", do_median);
Dialog.addNumber("  Radius (px):", med_r);
Dialog.addCheckbox("Gaussian Blur", do_gaussian);
Dialog.addNumber("  Sigma (px):", gauss_s);
if (!isBatch)
    Dialog.addMessage(
        "-----------------------------------------------\n" +
        "After these filters you can apply additional manual\n" +
        "filters before thresholding (Single mode only).");
Dialog.show();

do_rb       = Dialog.getCheckbox();   rb_r     = Dialog.getNumber();
do_tophat   = Dialog.getCheckbox();   tophat_r = Dialog.getNumber();
do_median   = Dialog.getCheckbox();   med_r    = Dialog.getNumber();
do_gaussian = Dialog.getCheckbox();   gauss_s  = Dialog.getNumber();


// ─── Step 3: Threshold & Particle Settings ────────────────────────────
thr_methods = newArray("RenyiEntropy", "Otsu", "Triangle", "Default",
                       "Huang", "Intermodes", "IsoData", "Li",
                       "MaxEntropy", "Mean", "MinError", "Minimum",
                       "Moments", "Percentile", "Shanbhag", "Yen",
                       "Manual (interactive)");

// Manual threshold not available in batch mode: remove last entry
if (isBatch) {
    thr_methods = newArray("RenyiEntropy", "Otsu", "Triangle", "Default",
                           "Huang", "Intermodes", "IsoData", "Li",
                           "MaxEntropy", "Mean", "MinError", "Minimum",
                           "Moments", "Percentile", "Shanbhag", "Yen");
}

ch_a_lbl = "Channel A  (Ch " + g_chA_num + ")";
ch_b_lbl = "Channel B  (Ch " + g_chB_num + ")";

Dialog.create("Step 3 of 4  –  Threshold & Particle Analysis");
Dialog.addMessage(
    "Set the threshold method for each channel.\n" +
    "'Manual (interactive)' is only available in Single mode.");
Dialog.addMessage("----  " + ch_a_lbl + "  ----");
Dialog.addChoice("Threshold method:", thr_methods, g_thr1);
Dialog.addMessage("----  " + ch_b_lbl + "  ----");
Dialog.addChoice("Threshold method:", thr_methods, g_thr2);
Dialog.addMessage("----  Particle Analysis  (on colocalization mask)  ----");
Dialog.addNumber("Minimum object area (px2):", g_min_area);
Dialog.addNumber("Maximum object area (px2):", g_max_area);
Dialog.addCheckbox("Exclude objects touching image edges", g_excl_edges);
Dialog.show();

g_thr1       = Dialog.getChoice();
g_thr2       = Dialog.getChoice();
g_min_area   = Dialog.getNumber();
g_max_area   = Dialog.getNumber();
g_excl_edges = Dialog.getCheckbox();


// ════════════════════════════════════════════════════════════════════
//  SINGLE IMAGE MODE
// ════════════════════════════════════════════════════════════════════

if (!isBatch) {

    // ── Open image ────────────────────────────────────────────────────
    Dialog.create("Step 4 of 4  –  Image Input");
    Dialog.addCheckbox("Open image file now", true);
    Dialog.addMessage("Uncheck only if the image is already open in Fiji.");
    Dialog.show();
    open_now = Dialog.getCheckbox();

    if (open_now) {
        img_path = File.openDialog("Open image file  (CZI, TIF, LIF, etc.)");
        if (img_path == "" || img_path == "null")
            exit("No file selected. Cancelled.");
        open(img_path);
    }
    if (nImages == 0) exit("Error: No image open.");

    img1_id    = getImageID();
    img1_title = getTitle();
    getDimensions(img_w, img_h, nCh, img_slices, nFrames);

    base_name = img1_title;
    dot_pos   = lastIndexOf(base_name, ".");
    if (dot_pos > 0) base_name = substring(base_name, 0, dot_pos);

    print("Image    : " + img1_title);
    print("Size     : " + img_w + " x " + img_h + " px");
    print("Channels : " + nCh + "  |  Slices: " + img_slices + "\n");

    // ── Channel selection ─────────────────────────────────────────────
    ch1_orig_id = 0;
    ch2_orig_id = 0;
    ch1_label   = "Channel A";
    ch2_label   = "Channel B";

    if (nCh == 1) {
        showMessage("Single-Channel Image",
            "Only ONE channel detected.\n \n" +
            "Please select the second channel image.");
        path2 = File.openDialog("Open second channel image");
        if (path2 == "" || path2 == "null") exit("Cancelled.");
        open(path2);
        ch1_orig_id = img1_id;
        ch2_orig_id = getImageID();
        selectImage(ch1_orig_id); ch1_label = getTitle();
        selectImage(ch2_orig_id); ch2_label = getTitle();
        g_chA_num = 1;
        g_chB_num = 1;

    } else if (nCh == 2) {
        selectImage(img1_id);
        run("Duplicate...", "title=ChA_orig duplicate channels=1");
        ch1_orig_id = getImageID();
        ch1_label   = "Channel 1";
        selectImage(img1_id);
        run("Duplicate...", "title=ChB_orig duplicate channels=2");
        ch2_orig_id = getImageID();
        ch2_label   = "Channel 2";
        g_chA_num = 1;
        g_chB_num = 2;

    } else {
        ch_items = newArray(nCh);
        for (k = 0; k < nCh; k++) ch_items[k] = "Channel " + (k+1);
        Dialog.create("Select Channels  –  Multi-Channel Image");
        Dialog.addMessage("Found " + nCh + " channels. Select two to colocalize:");
        Dialog.addChoice("Channel A:", ch_items, ch_items[g_chA_num-1]);
        Dialog.addChoice("Channel B:", ch_items, ch_items[g_chB_num-1]);
        Dialog.show();
        chA_str   = Dialog.getChoice();
        chB_str   = Dialog.getChoice();
        g_chA_num = parseInt(substring(chA_str, 8));
        g_chB_num = parseInt(substring(chB_str, 8));
        ch1_label = chA_str;
        ch2_label = chB_str;
        selectImage(img1_id);
        run("Duplicate...", "title=ChA_orig duplicate channels="+g_chA_num);
        ch1_orig_id = getImageID();
        selectImage(img1_id);
        run("Duplicate...", "title=ChB_orig duplicate channels="+g_chB_num);
        ch2_orig_id = getImageID();
    }

    // ── Z-stack projection ────────────────────────────────────────────
    selectImage(ch1_orig_id); getDimensions(w, h, c, nSl1, nFr);
    selectImage(ch2_orig_id); getDimensions(w, h, c, nSl2, nFr);
    if (maxOf(nSl1, nSl2) > 1) {
        proj_items = newArray("Max Intensity", "Sum Slices",
                              "Average Intensity", "Median");
        Dialog.create("Z-Stack Projection");
        Dialog.addMessage("Z-stack detected. Select projection method:");
        Dialog.addChoice("Method:", proj_items, g_proj_method);
        Dialog.show();
        g_proj_method = Dialog.getChoice();
        ch1_orig_id = projectChannel(ch1_orig_id, g_proj_method, "ChA_orig");
        ch2_orig_id = projectChannel(ch2_orig_id, g_proj_method, "ChB_orig");
        print("Z-Projection: " + g_proj_method);
    }

    // ── Overwrite check ───────────────────────────────────────────────
    out_prefix = output_dir + base_name;
    out_prefix = checkOverwrite(out_prefix, base_name, output_dir);

    // ── Process single image ──────────────────────────────────────────
    print("─── Processing: " + img1_title + " ───────────────");
    processImage(ch1_orig_id, ch2_orig_id, ch1_label, ch2_label, out_prefix, 0);

    // ── Save settings for reuse ───────────────────────────────────────
    saveSettings(out_prefix);

    // ── Save log ──────────────────────────────────────────────────────
    saveLog(out_prefix);

    // ── Final display ─────────────────────────────────────────────────
    selectImage(ch1_orig_id); roiManager("Show All");
    selectImage(ch2_orig_id); roiManager("Show All");
    run("Tile");

    // ── End dialog ────────────────────────────────────────────────────
    Dialog.create("Analysis Complete");
    Dialog.addMessage(
        "Single image analysis complete!\n \n" +
        "Objects detected     : " + res_n_coloc                    + "\n" +
        "Total coloc. area    : " + d2s(res_total_area, 1) + " px2\n" +
        "Avg. intensity Ch A  : " + d2s(res_avg_chA, 2)            + "\n" +
        "Avg. intensity Ch B  : " + d2s(res_avg_chB, 2)            + "\n \n" +
        "Settings saved for reuse in batch mode.\n" +
        "Output folder: " + output_dir                             + "\n \n" +
        "-----------------------------------------------\n" +
        "Thank you for using a Münster Imaging Network macro!\n" +
        "microscopy@uni-muenster.de  ·  uni.ms/imagingnetwork");
    Dialog.show();


// ════════════════════════════════════════════════════════════════════
//  BATCH MODE
// ════════════════════════════════════════════════════════════════════

} else {

    list = getFileList(input_dir);
    list = Array.sort(list);
    n_total   = 0;
    n_ok      = 0;
    n_skip    = 0;
    batch_csv = "Image,Objects_Found,Total_Area_px2,Avg_ChA_Mean,Avg_ChB_Mean\n";

    // Count matching files for progress display
    for (i = 0; i < list.length; i++) {
        if (endsWith(toLowerCase(list[i]), toLowerCase(g_suffix))) n_total++;
    }
    print("Files to process: " + n_total + "\n");

    // ── Main batch loop ────────────────────────────────────────────────
    img_count = 0;
    for (i = 0; i < list.length; i++) {
        fname = list[i];
        if (!endsWith(toLowerCase(fname), toLowerCase(g_suffix))) continue;

        img_count++;
        print("─── [" + img_count + "/" + n_total + "]  " + fname + " ───");

        open(input_dir + fname);
        img_id    = getImageID();
        img_title = getTitle();
        getDimensions(iw, ih, img_nCh, img_nSl, img_nFr);

        // Build output prefix from filename
        fn_base = img_title;
        dp = lastIndexOf(fn_base, ".");
        if (dp > 0) fn_base = substring(fn_base, 0, dp);
        fn_prefix = output_dir + fn_base;

        // Validate channel count
        if (img_nCh < 2) {
            print("  SKIP: Single-channel image, colocalization requires 2 channels.");
            selectImage(img_id); close();
            n_skip++;
            continue;
        }
        if (img_nCh < g_chA_num || img_nCh < g_chB_num) {
            print("  SKIP: Only " + img_nCh + " channels found, but Ch" +
                  g_chA_num + " and Ch" + g_chB_num + " are required.");
            selectImage(img_id); close();
            n_skip++;
            continue;
        }

        // Extract the two channels
        selectImage(img_id);
        run("Duplicate...", "title=ChA_orig duplicate channels="+g_chA_num);
        ch1_id = getImageID();

        selectImage(img_id);
        run("Duplicate...", "title=ChB_orig duplicate channels="+g_chB_num);
        ch2_id = getImageID();

        selectImage(img_id); close();  // close original; duplicates remain

        // Z-projection if needed
        selectImage(ch1_id); getDimensions(ww, hh, cc, nsl, nfr);
        if (nsl > 1) ch1_id = projectChannel(ch1_id, g_proj_method, "ChA_orig");
        selectImage(ch2_id); getDimensions(ww, hh, cc, nsl, nfr);
        if (nsl > 1) ch2_id = projectChannel(ch2_id, g_proj_method, "ChB_orig");

        // Process image
        ch1_lbl = "Channel " + g_chA_num;
        ch2_lbl = "Channel " + g_chB_num;
        processImage(ch1_id, ch2_id, ch1_lbl, ch2_lbl, fn_prefix, 1);

        // Collect batch summary row
        batch_csv += fn_base + "," + res_n_coloc + "," +
                     d2s(res_total_area,1) + "," +
                     d2s(res_avg_chA,2) + "," + d2s(res_avg_chB,2) + "\n";
        n_ok++;

        // Close all remaining image windows for this iteration
        while (nImages > 0) {
            selectImage(nImages);
            close();
        }
    } // end batch loop

    // ── Save batch summary CSV ────────────────────────────────────────
    summary_path = output_dir + "Batch_Summary.csv";
    f = File.open(summary_path);
    print(f, batch_csv);
    File.close(f);
    print("\nBatch summary saved: " + summary_path);

    // ── Save settings for future runs ─────────────────────────────────
    saveSettings(output_dir + "Batch");

    // ── Print batch summary ───────────────────────────────────────────
    print("");
    print("-----------------------------------------------");
    print("   BATCH COMPLETE");
    print("-----------------------------------------------");
    print("  Total files    : " + n_total);
    print("  Processed OK   : " + n_ok);
    print("  Skipped/Failed : " + n_skip);
    print("  Output folder  : " + output_dir);
    print("-----------------------------------------------");

    // ── Save batch log ────────────────────────────────────────────────
    saveLog(output_dir + "Batch");

    // ── End dialog ────────────────────────────────────────────────────
    Dialog.create("Batch Processing Complete");
    Dialog.addMessage(
        "Batch processing finished!\n \n" +
        "Files processed : " + n_ok + " of " + n_total + "\n" +
        "Skipped/Failed  : " + n_skip                   + "\n \n" +
        "Output folder:\n" + output_dir                 + "\n \n" +
        "-----------------------------------------------\n" +
        "Thank you for using a Münster Imaging Network macro!\n" +
        "microscopy@uni-muenster.de  ·  uni.ms/imagingnetwork");
    Dialog.show();

} // end if/else isBatch


// ════════════════════════════════════════════════════════════════════
//  FUNCTIONS
// ════════════════════════════════════════════════════════════════════

// ── processImage ──────────────────────────────────────────────────────
// Core processing pipeline. Works on two already-opened, projected
// channel images (ch1_id, ch2_id). Saves all results to out_prefix.
// In batch mode (is_batch=1) skips all interactive steps.
// Sets global result variables: res_n_coloc, res_total_area,
// res_avg_chA, res_avg_chB.
function processImage(ch1_id, ch2_id, ch1_lbl, ch2_lbl, out_prefix, is_batch) {

    // -- Create working copies for filtering --------------------------
    setBatchMode(true);
    selectImage(ch1_id);
    run("Duplicate...", "title=ChA_proc");
    ch1_proc = getImageID();
    selectImage(ch2_id);
    run("Duplicate...", "title=ChB_proc");
    ch2_proc = getImageID();

    // -- Apply automated filters --------------------------------------
    print("  Filters - " + ch1_lbl + ":");
    applyFilters(ch1_proc);
    print("  Filters - " + ch2_lbl + ":");
    applyFilters(ch2_proc);

    // -- Exit batch mode (show proc images) ---------------------------
    selectImage(ch1_proc); setBatchMode("show");
    selectImage(ch2_proc); setBatchMode("show");
    setBatchMode(false);

    // -- Optional manual filter step (single mode only) ---------------
    if (!is_batch) {
        waitForUser("Optional  -  Apply Additional Filters Manually",
            "Processed images are displayed.\n \n" +
            "Apply any additional filters via Fiji menus\n" +
            "(e.g. Process > Filters).\n \n" +
            "   Work on:  'ChA_proc'  and  'ChB_proc'\n \n" +
            "Click OK to continue with thresholding.");
    }

    // -- Threshold each channel ---------------------------------------
    ch1_mask = applyThreshold(ch1_proc, g_thr1, ch1_lbl, is_batch);
    selectImage(ch1_mask); rename("Mask_ChA");

    ch2_mask = applyThreshold(ch2_proc, g_thr2, ch2_lbl, is_batch);
    selectImage(ch2_mask); rename("Mask_ChB");

    // -- Binary AND colocalization ------------------------------------
    imageCalculator("AND create", "Mask_ChA", "Mask_ChB");
    coloc_mask = getImageID();
    rename("Mask_Coloc");

    // -- Save masks ---------------------------------------------------
    selectImage(ch1_mask);  saveAs("Tiff", out_prefix + "_Mask_ChA.tif");
    selectImage(ch1_mask);  rename("Mask_ChA");
    selectImage(ch2_mask);  saveAs("Tiff", out_prefix + "_Mask_ChB.tif");
    selectImage(ch2_mask);  rename("Mask_ChB");
    selectImage(coloc_mask); saveAs("Tiff", out_prefix + "_Mask_Coloc.tif");
    selectImage(coloc_mask); rename("Mask_Coloc");

    // -- Particle analysis on colocalization mask ---------------------
    roiManager("reset");
    selectImage(coloc_mask);
    excl_str = "";
    if (g_excl_edges) excl_str = " exclude";

    run("Analyze Particles...",
        "size="+g_min_area+"-"+g_max_area+
        " circularity=0.00-1.00 show=Nothing" + excl_str + " clear include add");

    n_col = roiManager("count");
    print("  Objects found: " + n_col);

    if (n_col == 0) {
        print("  WARNING: No colocalized objects detected.");
        res_n_coloc = 0; res_total_area = 0;
        res_avg_chA = 0; res_avg_chB    = 0;
        return 0;
    }
    roiManager("Save", out_prefix + "_Coloc_ROIs.zip");

    // -- Measurements on original pixel data --------------------------
    run("Set Measurements...",
        "area mean standard integrated min redirect=None decimal=4");

    // Channel A
    selectImage(ch1_id);
    run("Clear Results");
    for (r = 0; r < n_col; r++) { roiManager("Select", r); run("Measure"); }
    chA_area   = newArray(n_col); chA_mean = newArray(n_col);
    chA_sd     = newArray(n_col); chA_min  = newArray(n_col);
    chA_max    = newArray(n_col); chA_idn  = newArray(n_col);
    for (r = 0; r < n_col; r++) {
        chA_area[r] = getResult("Area",   r);
        chA_mean[r] = getResult("Mean",   r);
        chA_sd[r]   = getResult("StdDev", r);
        chA_min[r]  = getResult("Min",    r);
        chA_max[r]  = getResult("Max",    r);
        chA_idn[r]  = getResult("IntDen", r);
    }

    // Channel B
    selectImage(ch2_id);
    run("Clear Results");
    for (r = 0; r < n_col; r++) { roiManager("Select", r); run("Measure"); }
    chB_mean = newArray(n_col); chB_sd  = newArray(n_col);
    chB_min  = newArray(n_col); chB_max = newArray(n_col);
    chB_idn  = newArray(n_col);
    for (r = 0; r < n_col; r++) {
        chB_mean[r] = getResult("Mean",   r);
        chB_sd[r]   = getResult("StdDev", r);
        chB_min[r]  = getResult("Min",    r);
        chB_max[r]  = getResult("Max",    r);
        chB_idn[r]  = getResult("IntDen", r);
    }

    // Combined results table
    run("Clear Results");
    tot_area = 0; sum_chA = 0; sum_chB = 0;
    for (r = 0; r < n_col; r++) {
        setResult("Object_Nr",  r, r+1);
        setResult("Area_px2",   r, chA_area[r]);
        setResult("ChA_Mean",   r, chA_mean[r]);
        setResult("ChA_StdDev", r, chA_sd[r]);
        setResult("ChA_Min",    r, chA_min[r]);
        setResult("ChA_Max",    r, chA_max[r]);
        setResult("ChA_IntDen", r, chA_idn[r]);
        setResult("ChB_Mean",   r, chB_mean[r]);
        setResult("ChB_StdDev", r, chB_sd[r]);
        setResult("ChB_Min",    r, chB_min[r]);
        setResult("ChB_Max",    r, chB_max[r]);
        setResult("ChB_IntDen", r, chB_idn[r]);
        tot_area += chA_area[r];
        sum_chA  += chA_mean[r];
        sum_chB  += chB_mean[r];
    }
    updateResults();
    saveAs("Results", out_prefix + "_Results.csv");

    // Set global results
    res_n_coloc    = n_col;
    res_total_area = tot_area;
    res_avg_chA    = sum_chA / n_col;
    res_avg_chB    = sum_chB / n_col;

    print("  Total area : " + d2s(tot_area,1) + " px2");
    print("  Avg ChA    : " + d2s(res_avg_chA,2) + "  |  Avg ChB: " + d2s(res_avg_chB,2));

    return n_col;
}


// ── applyFilters ──────────────────────────────────────────────────────
// Applies selected restoration filters. Order: RB > TopHat > Median > Gauss.
// Called while setBatchMode(true) is active.
function applyFilters(img_id) {
    selectImage(img_id);

    if (do_rb) {
        run("Subtract Background...", "rolling="+rb_r);
        print("    [OK] Rolling Ball  (r=" + rb_r + " px)");
    }
    if (do_tophat) {
        selectImage(img_id);
        src_title = getTitle();
        run("Duplicate...", "title=_TH_tmp_");
        th_id = getImageID();
        run("Minimum...", "radius="+tophat_r);
        run("Maximum...", "radius="+tophat_r);
        imageCalculator("Subtract", src_title, "_TH_tmp_");
        selectImage(th_id); close();
        selectImage(img_id);
        print("    [OK] Top-Hat  (r=" + tophat_r + " px)");
    }
    if (do_median) {
        selectImage(img_id);
        run("Median...", "radius="+med_r);
        print("    [OK] Median  (r=" + med_r + " px)");
    }
    if (do_gaussian) {
        selectImage(img_id);
        run("Gaussian Blur...", "sigma="+gauss_s);
        print("    [OK] Gaussian  (sigma=" + gauss_s + " px)");
    }
    if (!do_rb && !do_tophat && !do_median && !do_gaussian)
        print("    No automated filters selected.");
}


// ── applyThreshold ────────────────────────────────────────────────────
// Thresholds img_id and converts to binary mask. Returns mask image ID.
// In batch mode: always uses automatic method (no interactive dialog).
function applyThreshold(img_id, method, ch_label, is_batch) {
    selectImage(img_id);

    if (!is_batch && method == "Manual (interactive)") {
        run("Threshold...");
        waitForUser("Set Threshold  -  " + ch_label,
            "Adjust threshold for  '" + ch_label + "'.\n \n" +
            "Do NOT click 'Apply' in the Threshold dialog.\n" +
            "Click OK here when done.");
        getThreshold(lo, hi);
        if (lo == -1) {
            print("  No threshold set - using Otsu as fallback.");
            setAutoThreshold("Otsu dark");
        }
    } else {
        setAutoThreshold(method + " dark");
    }

    setOption("BlackBackground", true);
    run("Convert to Mask");
    print("  [OK] Threshold '" + method + "'  ->  " + ch_label);
    return getImageID();
}


// ── projectChannel ────────────────────────────────────────────────────
// Z-projects image, closes original, returns projected image ID.
function projectChannel(img_id, method, new_title) {
    selectImage(img_id);
    if (nSlices > 1) {
        run("Z Project...", "projection=["+method+"]");
        proj_id = getImageID();
        selectImage(img_id); close();
        selectImage(proj_id); rename(new_title);
        return proj_id;
    }
    return img_id;
}


// ── saveSettings ─────────────────────────────────────────────────────
// Saves all current settings to a text file (key=value format).
// This file can be loaded at the start of a batch run.
function saveSettings(prefix) {
    f = File.open(prefix + "_Settings.txt");
    print(f, "# Object-Based Colocalization Analyzer - Settings File");
    print(f, "# Münster Imaging Network");
    print(f, "# Saved: " + getTimestamp());
    print(f, "# Load this file in batch mode to reuse these parameters.");
    print(f, "");
    print(f, "[Filters]");
    print(f, "do_rb="       + do_rb);
    print(f, "rb_r="        + rb_r);
    print(f, "do_tophat="   + do_tophat);
    print(f, "tophat_r="    + tophat_r);
    print(f, "do_median="   + do_median);
    print(f, "med_r="       + med_r);
    print(f, "do_gaussian=" + do_gaussian);
    print(f, "gauss_s="     + gauss_s);
    print(f, "");
    print(f, "[Threshold]");
    print(f, "thr1="        + g_thr1);
    print(f, "thr2="        + g_thr2);
    print(f, "");
    print(f, "[Particles]");
    print(f, "min_area="    + g_min_area);
    print(f, "max_area="    + g_max_area);
    print(f, "excl_edges="  + g_excl_edges);
    print(f, "");
    print(f, "[Channels]");
    print(f, "chA_num="     + g_chA_num);
    print(f, "chB_num="     + g_chB_num);
    print(f, "proj_method=" + g_proj_method);
    print(f, "");
    print(f, "[Batch]");
    print(f, "suffix="      + g_suffix);
    File.close(f);
    print("Settings saved: " + prefix + "_Settings.txt");
}


// ── loadSettings ─────────────────────────────────────────────────────
// Reads a settings file and populates all global setting variables.
// Lines starting with # or [ are ignored (comments / section headers).
function loadSettings(filepath) {
    if (!File.exists(filepath)) {
        print("Settings file not found: " + filepath);
        return;
    }
    content = File.openAsString(filepath);
    lines   = split(content, "\n");
    n_loaded = 0;
    for (i = 0; i < lengthOf(lines); i++) {
        line = lines[i];
        line = replace(line, "\r", "");   // strip Windows CR
        if (startsWith(line, "#") || startsWith(line, "[") ||
            lengthOf(line) == 0) continue;
        eq  = indexOf(line, "=");
        if (eq < 0) continue;
        key = substring(line, 0, eq);
        val = substring(line, eq+1);

        if (key == "do_rb")       { do_rb       = 0; if (val == "1") do_rb       = 1; }
        if (key == "rb_r")        { rb_r        = parseFloat(val); }
        if (key == "do_tophat")   { do_tophat   = 0; if (val == "1") do_tophat   = 1; }
        if (key == "tophat_r")    { tophat_r    = parseFloat(val); }
        if (key == "do_median")   { do_median   = 0; if (val == "1") do_median   = 1; }
        if (key == "med_r")       { med_r       = parseFloat(val); }
        if (key == "do_gaussian") { do_gaussian = 0; if (val == "1") do_gaussian = 1; }
        if (key == "gauss_s")     { gauss_s     = parseFloat(val); }
        if (key == "thr1")        { g_thr1        = val; }
        if (key == "thr2")        { g_thr2        = val; }
        if (key == "min_area")    { g_min_area    = parseFloat(val); }
        if (key == "max_area")    { g_max_area    = parseFloat(val); }
        if (key == "excl_edges")  { g_excl_edges  = 0; if (val == "1") g_excl_edges = 1; }
        if (key == "chA_num")     { g_chA_num     = parseInt(val); }
        if (key == "chB_num")     { g_chB_num     = parseInt(val); }
        if (key == "proj_method") { g_proj_method = val; }
        if (key == "suffix")      { g_suffix      = val; }
        n_loaded++;
    }
    print("Settings loaded: " + n_loaded + " parameters from " + filepath);
}


// ── checkOverwrite ────────────────────────────────────────────────────
// Checks if output files exist and asks user what to do.
// Returns the (possibly updated) out_prefix string.
function checkOverwrite(out_prefix, base_name, output_dir) {
    if (File.exists(out_prefix + "_Results.csv") ||
        File.exists(out_prefix + "_Coloc_ROIs.zip")) {
        ts = getTimestamp();
        ow_items = newArray("Overwrite existing files",
                            "Rename with timestamp  [" + ts + "]",
                            "Cancel");
        Dialog.create("Warning  -  Output Files Already Exist");
        Dialog.addMessage(
            "Output files for  '" + base_name + "'\n" +
            "already exist in the output folder!\n ");
        Dialog.addRadioButtonGroup("How to proceed:",
                                   ow_items, 3, 1, ow_items[1]);
        Dialog.show();
        ow = Dialog.getRadioButton();
        if (ow == "Cancel") exit("Cancelled. No files changed.");
        if (startsWith(ow, "Rename"))
            out_prefix = output_dir + base_name + "_" + ts;
    }
    return out_prefix;
}


// ── saveLog ───────────────────────────────────────────────────────────
function saveLog(prefix) {
    if (isOpen("Log")) {
        selectWindow("Log");
        saveAs("Text", prefix + "_Log.txt");
    }
}


// ── getTimestamp ──────────────────────────────────────────────────────
function getTimestamp() {
    getDateAndTime(yr, mo, dow, dom, hr, mn, sc, ms);
    mo = mo + 1;
    ts = "" + yr;
    if (mo  < 10) ts += "0"; ts += "" + mo;
    if (dom < 10) ts += "0"; ts += "" + dom;
    ts += "_";
    if (hr < 10)  ts += "0"; ts += "" + hr;
    if (mn < 10)  ts += "0"; ts += "" + mn;
    if (sc < 10)  ts += "0"; ts += "" + sc;
    return ts;
}
