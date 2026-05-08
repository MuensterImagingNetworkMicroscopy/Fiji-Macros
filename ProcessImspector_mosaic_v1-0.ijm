/*
 * =====================================================================
 * Tile Stitching & Hyperstack Macro
 * =====================================================================
 * Written by:  Sarah Weischer
 *              Münster Imaging Network - Microscopy
 * Year:        2026
 * AI-assisted: Claude (Anthropic)
 *
 * Description:
 *   Processes multi-channel, multi-position, z-stack OME-TIFF tiles (Imspector, LVBT).
 *   Automatically detects grid size, channels, and z-slices from
 *   filenames, converts to Hyperstack, and stitches tiles using
 *   the Grid/Collection Stitching plugin. 
 *   Grid/Collection Stitchting Plugin: 
 *   Preibisch, S., Saalfeld, S., & Tomancak, P. (2009). 
 *   Globally optimal stitching of tiled 3D microscopic image acquisitions. Bioinformatics, 25(11), 1463–1465. 
 *   doi:10.1093/bioinformatics/btp184
 *
 * Filename pattern:
 *   *[P_1] [XX x XX]_C00_xyz-Table Z0000.ome.tif
 *
 * All macros are licensed under the Creative Commons Attribution 4.0 International License.
 * You are free to use, modify, and redistribute them, provided that appropriate credit is given.
 * =====================================================================
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".ome.tif") suffix
#@ String(label = "Tile overlap", value = "20") overlap
#@ String (label = "Channel Names (comma separated, in acquisition order)", value = "DAPI,GFP") chString
#@ String (label = "Pixel Size (xy) in microns", value = "0.534") pixS
#@ String (label = "Pixel Size (z) in microns", value = "3") pixD
#@ Boolean (label = "Perform stitching?", value = true) bool_stitch


processFolder(input);

function processFolder(input) {
    list = getFileList(input);
    list = Array.sort(list);

    // --- Collect unique mosaic positions ---
    positions = newArray(list.length);
    posCount = 0;

    for (i = 0; i < list.length; i++) {
        if (endsWith(list[i], suffix)) {
            pos = extractPosition(list[i]);
            if (pos != "" && !arrayContains(positions, posCount, pos)) {
                positions[posCount] = pos;
                posCount++;
            }
        }
    }

    // --- Count channels and z-slices ---
    nCh = countMax(list, suffix, "_C", "_");
    nZ  = countMax(list, suffix, " Z", ".");
    print("Channels: " + nCh + " | Z-Slices: " + nZ);

    // --- Get grid dimensions from mosaic position strings ---
    gridX = 0;
    gridY = 0;
    for (p = 0; p < posCount; p++) {
        xy   = split(positions[p], " x ");
        xVal = parseInt(xy[0]);
        yVal = parseInt(xy[1]);
        if (xVal > gridX) gridX = xVal;
        if (yVal > gridY) gridY = yVal;
    }
    gridX = gridX + 1;  // zero-based → count
    gridY = gridY + 1;
    print("Grid: " + gridX + " x " + gridY);

    // --- Base name from input folder ---
    parts    = split(input, "\\");
    baseName = parts[parts.length - 1];

	// --- Process each unique mosaic position ---
	for (p = 0; p < posCount; p++) {
    	print("Processing mosaic position: [" + positions[p] + "]");
    	processFile(input, output, positions[p], nCh, nZ);
		}

	// --- Stitch all tiles ---
	if (bool_stitch) {
	    filePattern = baseName + "_{xx}_x_{yy}.tif";
	    print("Stitching with pattern: " + filePattern);
	
	    run("Grid/Collection stitching",
	        "type=[Filename defined position] " +
	        "order=[Defined by filename         ] " +
	        "grid_size_x=" + gridX + " " +
	        "grid_size_y=" + gridY + " " +
	        "tile_overlap=" + overlap + " " +
	        "first_file_index_x=0 " +
	        "first_file_index_y=0 " +
	        "directory=" + output + " " +
	        "file_names=" + filePattern + " " +
	        "output_textfile_name=TileConfiguration.txt " +
	        "fusion_method=[Linear Blending] " +
	        "regression_threshold=0.30 " +
	        "max/avg_displacement_threshold=2.50 " +
	        "absolute_displacement_threshold=3.50 " +
	        "compute_overlap " +
	        "computation_parameters=[Save memory (but be slower)] " +
	        "image_output=[Fuse and display]");
	
	    // Set pixel size and stack properties
	    run("Properties...",
	        "channels=" + nCh +
	        " slices=" + nZ +
	        " frames=1" +
	        " pixel_width="  + pixS +
	        " pixel_height=" + pixS +
	        " voxel_depth="  + pixD);

		
		// Split channel names and assign
	    chNames = split(chString, ",");
	    for (c = 1; c <= nCh; c++) {
	        Stack.setChannel(c);
	        if (c <= chNames.length) {
	            setMetadata("Label", chNames[c-1]);
	        } else {
	            setMetadata("Label", "C" + (c-1));  // fallback if fewer names than channels
	        }
    }
	        
		outPath  = output + File.separator + baseName + "_stitched.tif";
	    print("Saving to: " + outPath);
	    saveAs("Tiff", outPath);
	    close("*");
		}
	}

function processFile(input, output, position, nCh, nZ) {
    print("Processing: " + input + " | Position: [" + position + "]");

    File.openSequence(input, "filter=[" + position + "]");

    run("Stack to Hyperstack...",
        "order=xyzct channels=" + nCh +
        " slices=" + nZ +
        " frames=1 display=Composite");
    // Get the last folder name from input path as base name
	parts    = split(input, "\\");
	baseName = parts[parts.length - 1];
		    // Set pixel size and stack properties
	run("Properties...",
	        "channels=" + nCh +
	        " slices=" + nZ +
	        " frames=1" +
	        " pixel_width="  + pixS +
	        " pixel_height=" + pixS +
	        " voxel_depth="  + pixD);
	
	// Split channel names and assign
    chNames = split(chString, ",");
    for (c = 1; c <= nCh; c++) {
        Stack.setChannel(c);
        if (c <= chNames.length) {
            setMetadata("Label", chNames[c-1]);
        } else {
            setMetadata("Label", "C" + (c-1));  // fallback if fewer names than channels
        }
    }

    Stack.setDisplayMode("composite");
     
	
	// Create dataset folder
	outFolder = output + File.separator + baseName;
	File.makeDirectory(outFolder);
	outPath  = outFolder + File.separator + baseName + "_" + replace(position, " ", "_") + ".tif";
    print("Saving to: " + outPath);
    saveAs("Tiff", outPath);
    close();
}

// --- Count how many unique values follow a tag (e.g. "_C" or " Z") ---
// Extracts the zero-padded number after 'tag' and before 'stopChar'
// Returns the COUNT (max index + 1)
function countMax(list, suffix, tag, stopChar) {
    maxVal = 0;
    for (i = 0; i < list.length; i++) {
        if (!endsWith(list[i], suffix)) continue;
        idx = indexOf(list[i], tag);
        if (idx < 0) continue;
        numStart = idx + lengthOf(tag);
        numEnd   = indexOf(list[i], stopChar, numStart);
        if (numEnd < 0) continue;
        numStr = substring(list[i], numStart, numEnd);
        val = parseInt(numStr);
        if (val > maxVal) maxVal = val;
    }
    return maxVal + 1;  // zero-based index → count
}

// --- Extract mosaic position: last [...] group before "_C" ---
function extractPosition(filename) {
    pos = "";
    searchFrom = 0;
    cIndex = indexOf(filename, "_C");

    while (true) {
        start = indexOf(filename, "[", searchFrom);
        if (start < 0 || start > cIndex) break;
        end = indexOf(filename, "]", start);
        if (end < 0) break;
        pos = substring(filename, start + 1, end);
        searchFrom = end + 1;
    }
    return pos;
}

// --- Check if value already exists in array (up to count) ---
function arrayContains(arr, count, val) {
    for (k = 0; k < count; k++) {
        if (arr[k] == val) return true;
    }
    return false;
}