 /*   <Synaptonemal&CO Analyzer: recombination analysis in fluorecence images.>
    Copyright (C) 2021  Joaquim Soriano Felipe

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    The author can be contacted through joaquim.soriano@uclm.es or writting  to
    Joaquim Soriano Felipe, Facultad de Medicina, C/Almansa 14, 02008 Albacete.
    Albacete.Spain.*/
/*
 * Please notice this work is based on a publication: 
 *The macro installs some functions, it needs to be copied to the plugins folder. If the file name of the macro is changed, change the line <<run("Install...",>>
 *accordingly.
 *The aim of the macro is to automate crossover (CO) sites counting, CO localization along the synaptonemal complex (SC) and total SC measuring.
 *The macro works on three channel .lsm images on the same folder that are analyzed sequentially. Once launched, a series of GUI's instruct the user how to proceed. 
 *An image is opened, the user is asked to draw a ROI containing a nucleus, SC in the nucleus are threholded and its skeletons obtained (an 
 *additional step allows the user to correct threshold errors and overlapping SCs). Then, CO sites are thresholded and its center of mass 
 *obtained (an additional step allows the user to correct wrongly detected CO sites). A function locates each CO to the nearest SC. Finally, the length between COs in 
 *each SC is computed.
 *Latter developer version gives the chance (through a GUI) to analyze only SCs or SCs+COs.
 *Latter developer version implements a manual CO detection choice.
 *Latter developer version implements a menu to choose the channels showing SCs, COs and nuclei (if any). Allows for opening any Bioformats image, not just .lsm
 *Possible image channels combinations: 
 *				-single image showing SCs
 *				-two images, one showing SCs and the other one showing COs
 *			    -an extra image containing nuclei (DNA stainning) can be added to the latter case. If this image exists it will be used latter on to compute 
 *				 the centromere location. Distances will be computed relative to this location if DNA stainning image does exist, otherwise, it will be computed 
 *				 relative to the upper left position of the SCs.			 			 
 *It is possible (thouhg not easy and technicably questionble) to compute a single image for SCs and COs. The image could be a COs staining in which the SCs are visible in the background.
 *In order to process such image, select "Compute SCs and Crossovers sites", if the image is a single image channel, the macro will perfectly work.
 *Adapting the macro to referees' coments
 *2- open images using bioformats
 *3- create a function containing CO processing step
 *4- create a function containing SC processing step
 *5- adapt the macro to allow for working on images with a specific centromere label//In progress
 *		- modify GUI to choose channels content (no need to detect centromeres of any kind y SC analysis only)-DONE
 *		- modify function measure to work with different objects
 *		- modify the macro to add a correction step that checks that no more than 1 centromere per SC is selected
 *6- adapt the macro to the condition than the number of centromeres per SC ==1 or 0
 *7- adapt the macro to create means to aid relocating COs and centromeres out of SCs during the correction step
 *8- adapt the macro to not allow for choosing two channels with the same content 
 */
//MACRO SETUP
var SCsSlice=NaN;
var COsSlice=NaN;
var nucleiSlice=NaN;
var centromereSlice=NaN;
var computeAllBoolean=NaN;
var booleanAutomaticCODetection=NaN;
var booleanHappyCODetection=NaN;
var unit, pixelWidth, pixelHeight, sliceNumber;
var SCsArray;
var imageResultsDir;
var imageTitle;
var fileExtension;
fs=File.separator;
Dialog.create("Synaptonemal & CO analyzer");
Dialog.addMessage("Once pressing \"OK\", all open images, the Log, the ROI Manager and the Results window will be closed or reseted.\nYou can press \"i\" anytime to exit the macro.");
Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
Dialog.show();
print("\\Clear");//reset the log window
close("*");//close all images windows
windowsArray=getList("window.titles");//next block closes all non-image open windows, including results ones
for(i=0; i<lengthOf(windowsArray);i++)
{
	selectWindow(windowsArray[i]);
	run("Close");
}
if(isOpen("Results"))//close the results window
{
	selectWindow("Results");
	run("Close");
}
roiManager("reset");//reset the ROI manager
run("Options...", "iterations=1 count=1 black");//sets binary options
//MACRO BEGINS
//INSTALL FUNCTIONS WRITTEN IN THIS MACRO
run("Install...", "install="+getDirectory("plugins")+"Synaptonemal_&_CO_analyzer-12.ijm");//If the macro's file name is changed, change it here accordingly
representativeImageName=File.openDialog("Choose an image in the images' folder.\nThe macro will analyze all images of the same kind in the folder one after another.");
fileExtension=substring(representativeImageName, lastIndexOf(representativeImageName,"."));
//print("fileExtension: "+fileExtension);
dir=File.directory;
//print("dir: "+dir);
dirFileListArray=getFileList(dir);//Get image's path
resultsDir=dir+fs+"Results";
//Array.print(dirFileListArray);
Dialog.create("Synaptonemal & CO analyzer");
Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
itemsMenu1=newArray("Compute SCs and COs sites", "Compute only SCs");
Dialog.addChoice("How would you like to proceed?", itemsMenu1, itemsMenu1[0]);
Dialog.show();
stringComputeAllBoolean=Dialog.getChoice();
if(stringComputeAllBoolean==itemsMenu1[0])
{
	computeAllBoolean=1;//computeAllBoolean= true->SCs and COs will be computed; if false-> only SCs will be computed.
}
else
{
	computeAllBoolean=0;//computeAllBoolean= true->SCs and COs will be computed; if false-> only SCs will be computed.
}
//print("computeAllBoolean: "+computeAllBoolean);
File.makeDirectory(resultsDir);//Create a Results folder
//Create a menu to assign each image content (SC, CO, nuclei or centromere)
menuShown=0;//0 if the menu has not been shown yet, 1 otherwise
for(i=0; i<lengthOf(dirFileListArray);i++)
{//loop for each file in image's path
	if(endsWith(dirFileListArray[i], fileExtension))
	{//loop for each fileExtension image in image's path
		if(menuShown==0)
		{
			call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.25*screenHeight);
			run("Bio-Formats", "open=["+dir+dirFileListArray[i]+"] color_mode=Colorized rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder using bioformats importer plugin
			//open(dir+dirFileListArray[i]);//Open fileExtension files in image's folder using imageJ's open command
			id1=getImageID();
			getPixelSize(unit, pixelWidth, pixelHeight);
			sliceNumber=nSlices;	
			if(sliceNumber!=1)//The menu to choose image content will only be shown once if the image contains more than one channel, if it contains a single channel, then it is assumed to contain only SCs
			{
				call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.43*screenHeight);
				run("Make Montage...", "columns="+nSlices+" rows=1 scale=1 font=50 border=20 label");
				montageID=getImageID();
				selectImage(id1);
				close();
				//print("SCsSlice: "+SCsSlice);
				menuShown=1;
				do{
					uncorrectMenuChoices=false;
					Dialog.create("Synaptonemal & CO analyzer");
					Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
					if(computeAllBoolean==1)
					{Dialog.addMessage("Enter the number under the SCs image and the COs image. The nucleus image and the centromeres image are optional, choose one of them to compute COs positios relative to:\n. - the most intense SC end (usually centromeres in mice)\n - centromeres position\n Enter 0 if any of this image does not exist\n In case neither nuclei nor centromere images exist, distances will be not computed relative to the centromere but to the left most SC position.\nE.g.: enter 1 in the first field if the image showing the SCs is the first in the series.");}
					else //if no COs are not going to be analyzed, change the menu text so they are not mentioned nor are nuclei and centromere images
					{Dialog.addMessage("Enter the number under the SCs image.\nE.g.: enter 1 in the first field if the image showing the SCs is the first in the series.");}
					Dialog.addNumber("SCs are in image: ", 1, 0, 1, "");
					if(computeAllBoolean==1){
						Dialog.addNumber("COs are in image: ", 2, 0, 1, "");//if the COs are not going to be analyzed, there is no need to know in which image they are (if any)
						Dialog.addNumber("Nuclei are in image: ", 0, 0, 1, "");//if no COs are not going to be analyzed there is no need to know their positions relative the centromere
						Dialog.addNumber("Centromeres are in image: ", 0, 0, 1, "");//if no COs are not going to be analyzed there is no need to know their positions relative the centromere
						}
					Dialog.show();
					SCsSlice=Dialog.getNumber();
					if(computeAllBoolean==1){
						COsSlice=Dialog.getNumber();//if the COs are not going to be analyzed, there is no need to know in which image they are (if any)
						nucleiSlice=Dialog.getNumber();//if no COs are not going to be analyzed there is no need to know their positions relative the centromere
						centromereSlice=Dialog.getNumber();//if no COs are not going to be analyzed there is no need to know their positions relative the centromere
						}
					if(SCsSlice==0)
					{
						uncorrectMenuChoices=true;
						showMessage("No image containing SCs has been selected, please choose the image containing SCs.");
					}
					if(computeAllBoolean==1 && COsSlice==0)
					{
						uncorrectMenuChoices=true;
						showMessage("No image containing COS has been selected, please choose the image containing COs.");
					}

					//Next code checks that there are not equal values (different to 0) for SCsSlice, COsSlice, nucleiSlice and centromereSlice
					channelsArrayValue=newArray(SCsSlice, COsSlice, nucleiSlice, centromereSlice);
					channelsArrayContent=newArray("SCs", "COs", "nuclei", "centromeres");
					//print("channelsArrayValue: ");
					//Array.print(channelsArrayValue);
					for(r=0;r<lengthOf(channelsArrayValue)-1;r++)
					{
						for(s=r+1;s<=lengthOf(channelsArrayValue)-1;s++)
						{
							if(channelsArrayValue[r]==channelsArrayValue[s] && channelsArrayValue[r]!=0)
							{
								uncorrectMenuChoices=true;
								showMessage("You need to choose different images for "+channelsArrayContent[r]+" and "+channelsArrayContent[s]+" .");
							}
							
						}
						
					}
					if(nucleiSlice!=0 && centromereSlice!=0 && computeAllBoolean==1)
					{
						uncorrectMenuChoices=true;
						showMessage("Two images (nuclei and centromeres) have been choosen to detect centromeres position, please choose only one.");
					}
				}
				while(uncorrectMenuChoices)
				if(isOpen(montageID))
				{
					selectImage(montageID);
					close();	
				}
				
			}
			else if(sliceNumber==1)//If the image is a single channel one, then it is assumed that it does only contain SCs
			{
				SCsSlice=1;//Check if this info is meaningful latter on
				COsSlice=0;
				nucleiSlice=0;
				centromereSlice=0;
			}
			//print("SCsSlice: "+SCsSlice+", COsSlice: "+COsSlice+", nucleiSlice: "+nucleiSlice);

		}//end of if(menuShown)
		//Next block empties de results folder for the image under analysis if it does already exist
		imageResultsDir=resultsDir+fs+dirFileListArray[i];
		if(File.exists(imageResultsDir))
		{
			Dialog.create("Synaptonemal & CO analyzer");
			Dialog.addMessage("There is already a results folder: "+dirFileListArray[i]+".\nIts contents will be overwritten.\nIf you do not want this to happen, change the folder's name or move it to a different location.\nPress \"OK\" afterwards.");
			Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
			Dialog.show();
			//Erase the content of each image results folder, otherwise if a "SCs only analysis" is done after a complete one, the COs results are not overwritten 
			toEraseDir=imageResultsDir+fs;
			//print("toEraseDir: "+toEraseDir);
			toEraseFiles=getFileList(toEraseDir);
			nFilesToErase=lengthOf(toEraseFiles);
			for(q=0;q<nFilesToErase;q++)
			{
				toErasePath=toEraseDir+toEraseFiles[q];
				//print("toErasePath: "+toErasePath);
				File.delete(toErasePath);	
			}	
		}
		File.makeDirectory(imageResultsDir);//create a folder in the results folder for each analyzed image
		if(sliceNumber!=1)
		{
			call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.24*screenHeight);
			run("Bio-Formats", "open=["+dir+dirFileListArray[i]+"] color_mode=Colorized rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder
			//open(dir+dirFileListArray[i]);//Open fileExtension files in image's folder
			id=getImageID();
		}
		else{id=id1;}
		setTool("polygon");
		run("ROI Manager...");
		severalSelections=false;
		do//ask the user to do a selection containing a nucleus and add it to the ROI Manager. Check that it's done or ask if all nucleus in the image should be processed.
		{
			if(severalSelections==false){
				Dialog.createNonBlocking("Synaptonemal & CO analyzer");
				Dialog.addMessage("Choose a nucleus.\nAdd it to the ROI Manager.\nPress \"OK\" afterwards.");
				Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
				Dialog.show();				
			}
			else{
				Dialog.createNonBlocking("Synaptonemal & CO analyzer");
				Dialog.addMessage("More than a selection has been done.\nMake sure that there is only one nucleus selection in the ROI Manager.\nPress \"OK\" afterwards.");
				Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
				Dialog.show();					
			}
			if(roiManager("count")==0)
			{
				Dialog.create("Synaptonemal & CO analyzer");
				Dialog.addMessage("The ROI Manager is empty, would you like to continue?:");
				Dialog.addCheckbox("Check to process all nuclei in the image, otherwise you will be asked to select a nucleus again.", false);
				Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
				Dialog.show();
				continueWithoutSelection=Dialog.getCheckbox();
				if(continueWithoutSelection==1)
				{
					run("Select All");
					roiManager("add");
				}
			}	
			else if(roiManager("count")>1)
			{
				severalSelections=true;
			}
		}
		while(roiManager("count")!=1)
		selectionKindBeforeCroping=selectionType();
		//print("selectionKindBeforeCroping: "+selectionKindBeforeCroping);
		run("Crop");//Decrease image size by getting rid of the image not containing nucleus
		roiManager("reset");
		if(selectionKindBeforeCroping==0 && selectionType==-1)//when the selection is a rectangle and is not selection all the image, the selection disappears after cropping, causing an error (other selectiont types stay after cropping)
		{
			run("Restore Selection");
		}
		roiManager("add");
		roiManager("select", 0);
		roiManager("rename", "nucleus-1");
		roiManager("save selected", imageResultsDir+fs+"nucleus.zip");//Save the nucleus selection in the image results folder
		imageTitle=getTitle();
		run("Select None");
		saveAs("tiff", imageResultsDir+fs+imageTitle);
		rename(imageTitle);
		//get rid of all images but the one containing the SCs
		selectSlice(SCsSlice);
		rename("SCs BINARY");//Single channel image that is going to containt the binary SCs
		roiManager("select", 0);
		setBackgroundColor(0, 0, 0);
		run("Clear Outside");//Erase anything outside the nucleus
		roiManager("Select", 0);
		roiManager("Deselect");
		run("Select None");
		SC_analysis();//Reduces SCs to a binary image of its skeletons
		//run("Skeletonize");
		run("Create Selection");
		roiManager("Add");
		run("Select None");
		//run("Bio-Formats", "open=["+imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif")+"] color_mode=Colorized rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT")
		call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.41*screenHeight);
		open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));
		rename(imageTitle);
		rename("SCs 8-BIT");//Single channel image that is going to containt the 8-bit SCs
		selectSlice(SCsSlice);
		roiManager("Deselect");
		roiManager("select", 0);
		run("Crop");
		setBackgroundColor(0, 0, 0);
		run("Clear Outside");
		roiManager("Select", 0);
		roiManager("Delete");
		run("Select None");
		//This code arranges opened images one at the right side of the other.
		syncImageList=getList("image.titles");
		for(w=0;w<lengthOf(syncImageList);w++)
		{
			if(w==0)
			{
				selectWindow(syncImageList[0]);
				getLocationAndSize(unusedX, unusedY, syncImageWidth, unusedHeight);
				setLocation(0.01*screenWidth, 0.31*screenHeight);
			}
			else 
			{
				selectWindow(syncImageList[w]);
				setLocation((0.01*screenWidth+syncImageWidth)*w,0.31*screenHeight);
			}
		}
		roiManager("select", 0);
		Overlay.addSelection;//Skeletonized SCs are shown as an overlay over the SCs 8-BIT image
		roiManager("show all without labels");
		roiManager("show none");
		run("Synchronize Windows");
		setForegroundColor(0, 0, 0);
		setTool("rectangle");
		selectWindow("Threshold");
		run("Close");
		//Zoom of both "SCs 8-BIT" and "SCs BINARY" images is set the same if it is not
		selectWindow("SCs 8-BIT");
		Overlay.selectable(false);//prevents overlays from being selectable, which causes trouble latter on when modifying SCs selection. Needs to be executed on every image.
		zoom8Bit=getZoom();
		selectWindow("SCs BINARY");
		Overlay.selectable(false);//prevents overlays from being selectable, which causes trouble latter on when modifying SCs selection. Needs to be executed on every image.
		zoomBinary=getZoom();
		if(zoomBinary!=zoom8Bit)
		{
			getDimensions(width, height, channels, slices, frames);
			//print(floor(width/2));
			//print(floor(height/2));
			run("Set... ", "zoom="+zoom8Bit*100+" x="+floor(width/2)+" y="+floor(height/2)+"");
		}		
		//Windows sinchronization has to be done by the user because "Sync Windows" commands are not saved by the recorder
		//Next block of code is going to allow the user to modify detected SCs by drawing or erasing over the binary image
		do
		{
			branchingPoints=false;//SCs are assumed to be linear, latter on they are checked for branching points and ask the user to correct them if necessary
			Dialog.createNonBlocking("Synaptonemal & CO analyzer");
			Dialog.addMessage("*****SCs-DETECTION CORRECTION*****\n  \nSynchronize the windows \"SCs 8-BIT\" and \"SCs BINARY\".\nCreate a selection on the image \"SCs BINARY\" and press \"d\" to draw or \"e\" to erase.\nUse this tool to get rid of X and Y chromosomes.\nTo correct overlapping SCs, choose an image, then press \"o\".\nPress \"OK\" once you are done correcting SCs.");
			Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
			Dialog.show();
			//If no image is selected before pressing "o" nothing will be done. The image needs to be selected so the waitForUser menu is not selected.
			//delete all SCs in the roiManager but the ones that have been corrected using the overlap macro
			nonOverlapingSCs=0;
			overlapingSCs=0;
			for(v=0;v<roiManager("count");v++)
			{
				roiName=call("ij.plugin.frame.RoiManager.getName", v);
				if(roiName!="overlap")
				{
					nonOverlapingSCs++;
				}
				else if(roiName == "overlap")
				{
					overlapingSCs++;
				}
			}
			deleteArray=newArray(nonOverlapingSCs);
			deleteSCIndex=0;
			for(v=0;v<roiManager("count");v++)
			{
				roiName=call("ij.plugin.frame.RoiManager.getName", v);
				if(roiName!="overlap")
				{
					deleteArray[deleteSCIndex]=v;
					deleteSCIndex++;
				}
			}		
			roiManager("select", deleteArray);
			roiManager("delete");
			selectWindow("SCs BINARY");
			setThreshold(1, 255);
			run("Select None");
			run("Set Measurements...", "perimeter display redirect=None decimal=3");
			run("Analyze Particles...", "display exclude include add stack");//Measures SCs length, shows them in the results table, adds SCs to the ROI Manager
			selectWindow("SCs 8-BIT");
			Overlay.clear;
			selectWindow("SCs BINARY");
			Overlay.clear;			
			roiManager("select", Array.getSequence(roiManager("count")));
			roiManager("Combine");
			selectWindow("SCs 8-BIT");
			run("From ROI Manager");
			selectWindow("SCs BINARY");
			run("From ROI Manager");
			roiManager("show all without labels");
			roiManager("show none");
			roiManager("deselect");
			//Next code sorts the ROIManager window so "overlap" ROIs are the last ones. This assures that, later on, SCs names correspond to the SCs numbers shown by the ROIManager
			overlapDeleteArray=newArray(overlapingSCs);
			overlapDeleteArrayIndex=0;
			finalROINumber=roiManager("count");
			SCIndex=1;
			for(v=0;v<finalROINumber;v++)
			{
				roiName=call("ij.plugin.frame.RoiManager.getName", v);
				if(roiName == "overlap")
				{
					overlapDeleteArray[overlapDeleteArrayIndex]=v;
					overlapDeleteArrayIndex++;
					roiManager("select", v);
					roiManager("add");
					roiManager("select", roiManager("count")-1);
					roiManager("rename", "overlap");
					roiManager("deselect");
				}
				else
				{
					roiManager("select", v);
					roiManager("rename", "SC-"+SCIndex);
					roiManager("deselect");
					SCIndex++;
				}
			}
			if(overlapingSCs!=0)
			{
				roiManager("select", overlapDeleteArray);
				roiManager("delete");//deletes all ROIs when none of them is selected
			}
			selectWindow("SCs BINARY");
			run("Select None");
			run("Analyze Skeleton (2D/3D)", "prune=none");//look for branching points in SCs skeletons
			if(isOpen("Results"))
			{
				selectWindow("Results");
				run("Close");
			}
			selectWindow("Tagged skeleton");		
			String.resetBuffer;
			for(o=0;o<roiManager("count");o++)
			{
				roiManager("select",o);
				name2=call("ij.plugin.frame.RoiManager.getName", o);
				getSelectionCoordinates(xArrayCoords,yArrayCoords);//
				for(p=0;p<lengthOf(xArrayCoords);p++)
				{
					if(getPixel(xArrayCoords[p], yArrayCoords[p])==70)
					{
						String.append(name2+",");
						o++;			
						p=lengthOf(xArrayCoords);
						branchingPoints=true;
					}
				}
			}
			selectWindow("Tagged skeleton");
			close();
			roiManager("show all without labels");
			roiManager("show none");
			roiManager("show all with labels");
			if(branchingPoints)
			{
				Dialog.create("BRANCHING POINTS FOUND");
				Dialog.addMessage("At least one branching point has been found in the following SCs: "+String.buffer+"\nPress \"OK\", then erase them prior to continue.");
				Dialog.show();	
			}
		}
		while(branchingPoints)	
		for(k=0; k<roiManager("count"); k++)
		{
			roiManager("select", k);
			roiManager("rename", "SC-"+k+1);
		}	
		selectWindow("Synchronize Windows");
		run("Close");
		selectWindow("SCs BINARY");
		close();
		selectWindow("SCs 8-BIT");
		Overlay.hide;
		roiManager("show all with labels");
		nSCs=roiManager("count");
		//print("nSCs: "+nSCs);
		roiManager("save", imageResultsDir+fs+"synaptonemal_complexes.zip");//save SCs ROIs
		if(computeAllBoolean==false)
		{
			id4=getImageID();
			run("Select All");
			setForegroundColor(0, 0, 0);
			run("Fill", "slice");
			run("Select None");
			setForegroundColor(255, 255, 255);
			roiManager("select", Array.getSequence(roiManager("count")));
			roiManager("Fill");
			roiManager("deselect");
			run("Select None");
			run("Remove Overlay");
			Table.deleteRows(0, nResults);//resets the results window
			Table.create("SC's length_"+dirFileListArray[i]);
			for(k=0;k<roiManager("count");k++)
			{
				//print("SC-"+k+"-------------");
				startingPointArray=startingPoint(id4,k,0);//gets one starting coordinate of an SC at random
				//print("startingPointArray: ");
				//Array.print(startingPointArray);
				measure("SCs",k,startingPointArray[0],startingPointArray[1]);//gets the length of an SCs, prints it on a table
				selectWindow("SC's length_"+dirFileListArray[i]);
				Table.update;
			}
		}
		
		roiManager("show all without labels");
		roiManager("show none");
		run("Hide Overlay");
		close();
		
		if(computeAllBoolean==true)
		{
			COsDetectedBoolean=1;//0: no COs have been detected, 1: at least one CO has been detected. 
			//////////////CO SITES ANALYSIS BEGINS
			//open the channel containing COs as a single image and erase all info out of the nucleus
			call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.31*screenHeight);
			open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));
			rename(imageTitle);
			id2=getImageID();
			selectSlice(COsSlice);
			roiManager("Deselect");
			roiManager("open", imageResultsDir+fs+"nucleus.zip");
			roiManager("select", roiManager("count")-1);
			setBackgroundColor(0, 0, 0);
			run("Clear Outside");
			roiManager("select", roiManager("count")-1);
			roiManager("Delete");
			run("Select None");
			roiManager("show none");
			//Ask the user whether locating COs automatically or manually
			Dialog.create("Synaptonemal & CO analyzer");
			Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
			itemsMenu3=newArray("Yes", "No");
			Dialog.addChoice("Would you like to try to locate the COs automatically?", itemsMenu3, itemsMenu3[0]);
			Dialog.show();
			stringBooleanAutomaticCODetection=Dialog.getChoice();
			if(stringBooleanAutomaticCODetection==itemsMenu3[0])
			{
				booleanAutomaticCODetection=1;
			}
			else
			{
				booleanAutomaticCODetection=0;
			}
			if(booleanAutomaticCODetection)//detect COs automatically
			{
				CO_analysis();//creates a results table containing COs' centers of mass (aks the user to create selections over the background)
				xpoints=newArray(nResults);
				ypoints=newArray(nResults);
				for(k=0;k<nResults;k++)
				{
					//print(k);
					xpoints[k]=round(getResult("XM", k));
					ypoints[k]=round(getResult("YM", k));					
				}
				if(isOpen("Results"))//empty and close the results window
				{
					selectWindow("Results");
					Table.deleteRows(0, nResults);
					selectWindow("Results");
					run("Close");
				}
				selectImage(id2);
				close();
				call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.41*screenHeight);
				//open the COs channel as an image, gets rid of info out of the nucleus
				open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));
				rename(imageTitle);
				id2=getImageID();
				selectSlice(COsSlice);
				roiManager("Deselect");
				roiManager("open", imageResultsDir+fs+"nucleus.zip");
				roiManager("select", roiManager("count")-1);
				run("Crop");
				setBackgroundColor(0, 0, 0);
				run("Clear Outside", "stack");
				roiManager("select", roiManager("count")-1);
				roiManager("Delete");
				run("Select None");
				roiManager("show none");
				makeSelection("point", xpoints, ypoints);
				run("Point Tool...", "type=Circle color=Red size=Large show counter=0");//changes the stroke color for overlay and selections, changed to Yellow previously
				setTool("multipoint");
				//ask the user whether it wants to correct minor errors or do manual analysis
				Dialog.create("Synaptonemal & CO analyzer");
				Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
				itemsMenu2=newArray("Yes, correct minor errors manually if necessary", "No, erase all and let me locate COs manually");
				Dialog.addChoice("Are you happy with automatically detected COs?", itemsMenu2, itemsMenu2[0]);
				Dialog.show();
				open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));//This image is open and closed so the macro checkPositionsRelativeToSCs works properly (it opens the last opened image)
				close();
				stringBooleanHappyCODetection=Dialog.getChoice();
				if(stringBooleanHappyCODetection==itemsMenu2[0])
				{
					booleanHappyCODetection=1;
				}
				else
				{
					booleanHappyCODetection=0;
				}			
				if(booleanHappyCODetection)//correct minor errors manually
				{
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					Dialog.addMessage("Choose the \"Multi-point\" tool to modify the CO selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					//Next blok closes images opened by the macro checkPositionsRelativeToSCs if any
					while(isOpen("check position relative to SCs"))
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					if(selectionType==-1)
					{
						COsDetectedBoolean=0;
					}
				}
				else {//manual analysis of COs
					selectImage(id2);
					run("Select None");
					setTool("multipoint");
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					Dialog.addMessage("--- MANUAL COs DETECTION ---\n   \nChoose the \"Multi-point\" tool to modify the CO selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					if(selectionType==-1)
					{
						COsDetectedBoolean=0;
					}
				}
			}//end of if(booleanAutomaticCODetection)
			if(booleanAutomaticCODetection==false || COsDetectedBoolean==0) {//No COs were detected previously or the user wanted to select them manually
				do{
					setTool("multipoint");	
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					if(COsDetectedBoolean==0)
					{
						Dialog.addMessage("No COs were detected on the previous steps.\nAt least a CO should be detected, add at least one or interrupt the macro and do a \"Compute only SCs\" analysis instead.");
					}
					Dialog.addMessage("--- MANUAL COs DETECTION ---\nChoose the \"Multi-point\" tool to modify the CO selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					COsDetectedBoolean=0;
				}
				while(selectionType==-1)
			}
			getSelectionCoordinates(xpoints, ypoints);
			//Moved or created points coordinates might not be integers but it is convenient that they are: they need to be transformed
			for(k=0;k<lengthOf(xpoints);k++)
			{
				xpoints[k]=round(xpoints[k]);
				ypoints[k]=round(ypoints[k]);
			}		
			modXPoints=Array.copy(xpoints);
			modYPoints=Array.copy(ypoints);
			SCsArray=newArray(lengthOf(xpoints));//It is going to store the SC number in which the CO is contained, i.e. if the third CO is contained in the first SC, then SCsArray[2]=1;
			//Next code checks if a point falls over an SC, otherwise it is located over the closest one
			//If a point is equally close to two SCs it will be asigned to the one appearing first in the ROI Managers
			//Check that COs lay over SCs
			unasignedCounter=0;//it's going to count the number of COs that do no lay over an SC
			for(k=0;k<lengthOf(xpoints);k++)
			{
				unasigned=true;//true: the CO does not lay over a SC
				if(unasigned)
				{//checks if the CO is located inside a SC
					for(l=0;l<nSCs;l++)
					{
						roiManager("select", l);
						if(selectionContains(xpoints[k], ypoints[k]))
						{
							modXPoints[k]=xpoints[k];
							modYPoints[k]=ypoints[k];
							SCsArray[k]=l+1;						
							unasigned=false;	
							//print("The CO site in "+xpoints[k]+", "+ypoints[k]+" is inside the synaptonemal complex "+l+1);			
							l=nSCs;			
						}				
					}
				}
				if(unasigned)//Locates a CO site out of the SCs into the closest SC in a 3x3 matrix. If a CO is close to different SC, it will be assigned to the SC coming first in the ROI Manager.
				{
					aproximationArrayX=newArray(xpoints[k], xpoints[k]+1, xpoints[k], xpoints[k]-1, xpoints[k]+1, xpoints[k]+1, xpoints[k]-1, xpoints[k]-1, 
						xpoints[k], xpoints[k]+2, xpoints[k], xpoints[k]-2, xpoints[k]+1, xpoints[k]+2, xpoints[k]+2, xpoints[k]+1, xpoints[k]-1, xpoints[k]-2,
						xpoints[k]-2, xpoints[k]-1, xpoints[k]+2, xpoints[k]+2, xpoints[k]-2, xpoints[k]-2);
					aproximationArrayY=newArray(ypoints[k]-1, ypoints[k], ypoints[k]+1, ypoints[k], ypoints[k]-1, ypoints[k]+1, ypoints[k]+1, ypoints[k]-1, 
						ypoints[k]-2, ypoints[k], ypoints[k]+2, ypoints[k], ypoints[k]-2, ypoints[k]-1, ypoints[k]+1, ypoints[k]+2, ypoints[k]+2, ypoints[k]+1,
						ypoints[k]-1, ypoints[k]-2, ypoints[k]-2, ypoints[k]+2, ypoints[k]+2, ypoints[k]-2);
					for(l=0;l<nSCs;l++)
					{
						roiManager("select", l);			
						for(m=0; m<24; m++)
						{
							if(selectionContains(aproximationArrayX[m], aproximationArrayY[m]))
							{
								modXPoints[k]=aproximationArrayX[m];
								modYPoints[k]=aproximationArrayY[m];
								SCsArray[k]=l+1;		
								unasigned=false;	
								//print("The CO site in "+xpoints[k]+", "+ypoints[k]+" turned to "+aproximationArrayX[m]+", "+aproximationArrayY[m]+", which is inside synaptonemal complex "+l+1);
								m=24;
								l=nSCs;															
							}
						}
					}					
				}
				if(unasigned)//The CO site is neither in a SC nor closer than a 3x3 pixel  matrix.
				{
					selectWindow(dirFileListArray[i]);
					unasignedCounter++;
					//print("The CO site in "+xpoints[k]+", "+ypoints[k]+" has not been assigned to any synaptonemal complex or has been manually assigned");
					makePoint(xpoints[k], ypoints[k]);				
					run("Point Tool...", "type=Circle color=Red size=Large counter=0");
					continue1=false;//"continue" cannot be used
					error=false;
					do
					{//This loop can be exited drawing different ROIs as far as the selected one is a point selection. In this situarion, all ROIs but the last one will be ignored
						if(error==false)
						{
							Dialog.createNonBlocking("Synaptonemal & CO analyzer");
							Dialog.addMessage("The CO site at the screen has not been assigned to any synaptonemal complex.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the CO selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\n Select an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
							Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
							Dialog.show();
							while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
							{
								selectWindow("check position relative to SCs");
								close();
							}
							selectImage(id2);
							//waitForUser("The CO site at the screen has not been assigned to any synaptonemal complex.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the CO selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nPress \"OK\" afterwards.");
							}
						else
						{
							Dialog.createNonBlocking("Synaptonemal & CO analyzer");
							Dialog.addMessage("The selection is not a point selection, or it has not been moved nor deleted.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the CO selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
							Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
							Dialog.show();
							while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
							{
								selectWindow("check position relative to SCs");
								close();
							}
							selectImage(id2);
							//waitForUser("The selection is not a point selection, or it has not been moved nor deleted.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the CO selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nPress \"OK\" afterwards.");
							}
						if(selectionType()==-1)
						{
							//print("The CO site in:"+ modXPoints[k]+", "+modYPoints[k]+" has been deleted.");
							continue1=true;
						}
						else if(selectionType()==10)
						{
							getSelectionBounds(x, y, width, height);
							xpoints[k]=round(x);
							ypoints[k]=round(y);
							k--;
							continue1=true;
						}
						else{
							//print("The selection is not a point selection, or it has not been moved nor deleted.");
							error=true;
						}
					}
					while(continue1==false)
						
				}
			}
			run("Remove Overlay");//SCs overlay is removed
			//print("The number of CO sites that have not been automatically assigned to a SC is: "+unasignedCounter++);
			//print("xpoints: ");
			//Array.print(xpoints);
			//print("ypoints: ");
			//Array.print(ypoints);
			//print("modXPoints: ");
			//Array.print(modXPoints);
			//print("modYPoints: ");
			//Array.print(modYPoints);
			//print("SCsArray: ");
			//Array.print(SCsArray);
			roiManager("deselect");
			run("Select None");
			nDeletedPoints=0;
			for(k=0; k<lengthOf(modXPoints);k++)
			{
				if(SCsArray[k]==0)
				{
					nDeletedPoints++;
				}
			}
			finalPointsArrayX=newArray(lengthOf(modXPoints)-nDeletedPoints);//is going to contain the x coordinate of a SC point once checked that it lays over an SC
			finalPointsArrayY=newArray(lengthOf(modYPoints)-nDeletedPoints);//is going to contain the y coordinate of a SC point once checked that it lays over an SC	
			finalPointsArrayIndex=0;		
			for(k=0, l=0; k<lengthOf(modXPoints); k++)
			{
				if(SCsArray[k]!=0)
				{
					finalPointsArrayX[l]=modXPoints[k];
					finalPointsArrayY[l]=modYPoints[k];
					l++;
				}
			}
			//print("finalPointsArrayX: ");
			//Array.print(finalPointsArrayX);
			//print("finalPointsArrayY: ");
			//Array.print(finalPointsArrayY);
			roiManager("reset");
			makeSelection("point", finalPointsArrayX, finalPointsArrayY);
			run("Point Tool...", "type=Circle color=Yellow size=Large counter=0");
			resetThreshold();
			setTool("multipoint");
			roiManager("add");
			roiManager("select",0);
			roiManager("rename", "crossovers");
			roiManager("save", imageResultsDir+fs+"crossover_sites.zip");//save COs ROIs 
			roiManager("show all without labels");
			roiManager("show none");
			run("Hide Overlay");
			roiManager("reset");
			run("Select All");
			setForegroundColor(0, 0, 0);//creates a blank image from the already opened image
			run("Fill", "slice");
			run("Select None");
			roiManager("reset");
			roiManager("Open", imageResultsDir+fs+"synaptonemal_complexes.zip");//opens SCs ROIs
			setForegroundColor(255, 255, 255);//draw white SCs over a dark background
			roiManager("Fill");
			run("Set Measurements...", "area redirect=None decimal=0");
			roiManager("Measure");
			roiManager("reset");//close SCs ROIs
			roiManager("Open", imageResultsDir+fs+"crossover_sites.zip");//opens COs ROIs
			roiManager("Select", 0);
			setForegroundColor(0, 0, 0);//draw black COs over white SCs
			roiManager("Fill");
			roiManager("reset");//close COs ROIs
			run("Select None");
			roiManager("Open", imageResultsDir+fs+"synaptonemal_complexes.zip");//open SCs ROIs
			Table.deleteRows(0, nResults);//resets the results window
			Table.create("SC's length_"+dirFileListArray[i]);
			if(nucleiSlice!=0)//open the DAPI channel image if it was selcted by the user
			{
				call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.41*screenHeight);
				open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));//This is going to be the DAPI channel image
				id3=getImageID();//if this is set to 0, the starting point will be random from one of the two free sides of the SC
				selectSlice(nucleiSlice);				
			}
			else{id3=0;}
			xStartingPointsArray=newArray(nSCs);
			yStartingPointsArray=newArray(nSCs);
			for(k=0;k<roiManager("count");k++)
			{
				//print("SC-"+k+"-------------");
				var initialX, initialY;
				startingPointArray=startingPoint(id2,k,id3);//gets an starting point of each SC either at random (id3=0) or the most intense one (id3=identity of a nuclei staining channel image)
				//print("startingPointArray: ");
				//Array.print(startingPointArray);
				xStartingPointsArray[k]=startingPointArray[0];
				yStartingPointsArray[k]=startingPointArray[1];
				measure("COs",k,xStartingPointsArray[k],yStartingPointsArray[k]);//prints to a table partial lengths between COs an number of COs
				//selectWindow("SC's length_"+dirFileListArray[i]);
				//Table.update;
			}	

			//Next code saves startingPoints as a roiset (if centromere labeled analysis was performed) or centromeres as a roiset (if centromeres are suposed to be in the most intense nuclei staining end)
			if(nucleiSlice!=0){selectImage(id3);}//select the DAPI channel image if it does exist
			roiManager("reset");
			//Next code is going to create an arrow selection on every starting point or centromere
			for(k=0;k<nSCs;k++)
			{
				if(xStartingPointsArray[k]>10)
				{
					initialArrowX=xStartingPointsArray[k]-10;
				}
				else
				{
					initialArrowX=xStartingPointsArray[k]+10;
				}
				if(yStartingPointsArray[k]>10)
				{
					initialArrowY=yStartingPointsArray[k]-10;
				}
				else
				{
					initialArrowY=yStartingPointsArray[k]+10;
				}
				makeArrow(initialArrowX, initialArrowY, xStartingPointsArray[k], yStartingPointsArray[k], "notched outline");
				roiManager("add");
			}
			if(nucleiSlice!=0)//rename arrows as centromeres
			{
				for(z=0;z<roiManager("count");z++)
				{
					roiManager("select", z);
					roiManager("rename", "centromere-"+z+1);
				}				
			}
			else//rename arrows as starting points
			{
				for(z=0;z<roiManager("count");z++)
				{
					roiManager("select", z);
					roiManager("rename", "SC starting point-"+z+1);
				}				
			}		
			if(nucleiSlice!=0)//save centromeres positions or SCs starting points ROIs
			{roiManager("save", imageResultsDir+fs+"centromeres_positions.zip");}
			else{roiManager("save", imageResultsDir+fs+"SCs_starting_points.zip");}
			roiManager("reset");
			if(nucleiSlice!=0){close();}//close the DAPI channel image if it does exist
			selectImage(id2);
			close();//Run this line in order to check results in situ
		}
		//Next code updates and saves results table
		selectWindow("SC's length_"+dirFileListArray[i]);
		Table.update;
		roiManager("reset");

		if (centromereSlice!=0 && !isNaN(centromereSlice))
		{//centromere position analysis based on a centromere's probe begins
			centromereDetectedBoolean=1;//0: no centromeres have been detected, 1: at least one centromere has been detected. 
			call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.31*screenHeight);
			open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));
			rename(imageTitle);
			id2=getImageID();
			selectSlice(centromereSlice);//open the channel containing centromeres as an image
			roiManager("Deselect");
			roiManager("open", imageResultsDir+fs+"nucleus.zip");
			roiManager("select", roiManager("count")-1);
			setBackgroundColor(0, 0, 0);
			run("Clear Outside");//get rid of all info out of the nucleus
			roiManager("select", roiManager("count")-1);
			roiManager("Delete");
			run("Select None");
			roiManager("show none");
			//Ask the user whether to analyze centromeres either manually or automatically
			Dialog.create("Synaptonemal & CO analyzer");
			Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
			itemsMenu4=newArray("Yes", "No");
			Dialog.addChoice("Would you like to try to locate the centromeres automatically?", itemsMenu4, itemsMenu4[0]);
			Dialog.show();
			stringBooleanAutomaticCentromereDetection=Dialog.getChoice();
			if(stringBooleanAutomaticCentromereDetection==itemsMenu4[0])
			{
				booleanAutomaticCentromereDetection=1;
			}
			else
			{
				booleanAutomaticCentromereDetection=0;
			}
			if(booleanAutomaticCentromereDetection)//Analyze centromeres automatically
			{
				centromere_analysis();//returns a results table containing the centre of mass coordinates of centromeres
				xpoints=newArray(nResults);
				ypoints=newArray(nResults);
				for(k=0;k<nResults;k++)
				{
					//print(k);
					xpoints[k]=round(getResult("XM", k));
					ypoints[k]=round(getResult("YM", k));					
				}
				if(isOpen("Results"))//empty and close the results window
				{
					selectWindow("Results");
					Table.deleteRows(0, nResults);
					selectWindow("Results");
					run("Close");
				}
				selectImage(id2);
				close();
				call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.41*screenHeight);
				open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));//open the results image
				rename(imageTitle);
				id2=getImageID();
				selectSlice(centromereSlice);//get rid of all channels but the one containing centromeres
				roiManager("Deselect");
				roiManager("open", imageResultsDir+fs+"nucleus.zip");
				roiManager("select", roiManager("count")-1);
				run("Crop");//get rid of all the info out of the nucleus
				setBackgroundColor(0, 0, 0);
				run("Clear Outside", "stack");
				roiManager("select", roiManager("count")-1);
				roiManager("Delete");
				run("Select None");
				roiManager("show none");
				makeSelection("point", xpoints, ypoints);//show detected SCs as a selection
				run("Point Tool...", "type=Circle color=Red size=Large show counter=0");//changes the stroke color for overlay and selections, changed to Yellow previously
				setTool("multipoint");	
				Dialog.create("Synaptonemal & CO analyzer");
				Dialog.setLocation(0.01*screenWidth,0.01*screenHeight);
				itemsMenu2=newArray("Yes, correct minor errors manually if necessary", "No, erase all and let me locate centromeres manually");
				Dialog.addChoice("Are you happy with automatically detected centromeres?", itemsMenu2, itemsMenu2[0]);
				Dialog.show();
				open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));//This image is open and closed so the macro checkPositionsRelativeToSCs works properly (it opens the last opened image)
				close();
				stringBooleanHappyCentromereDetection=Dialog.getChoice();
				if(stringBooleanHappyCentromereDetection==itemsMenu2[0])
				{
					booleanHappyCentromereDetection=1;
				}
				else
				{
					booleanHappyCentromereDetection=0;
				}			
				if(booleanHappyCentromereDetection)//the user is happy with automatically detected centromeres, correct minor errors
				{
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					Dialog.addMessage("Choose the \"Multi-point\" tool to modify the centromeres' selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					if(selectionType==-1)//no centromeres were detected
					{
						centromereDetectedBoolean=0;
					}
				}
				else {//the user in not happy with automatically detected results, erase them and let him select them manually
					selectImage(id2);
					run("Select None");
					setTool("multipoint");
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					Dialog.addMessage("--- MANUAL CENTROMERES' DETECTION ---\n   \nChoose the \"Multi-point\" tool to modify the centromeres' selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					if(selectionType==-1)//no centromeres were detected
					{
						centromereDetectedBoolean=0;
					}
				}
			}//end of if(booleanAutomaticCentromereDetection)
			if(booleanAutomaticCentromereDetection==false || centromereDetectedBoolean==0) {//The user wants to detect centromeres manually or no centromeres were detected automatically
				do{
					setTool("multipoint");	
					Dialog.createNonBlocking("Synaptonemal & CO analyzer");
					if(centromereDetectedBoolean==0)
					{
						Dialog.addMessage("No Centromeres were detected on the previous steps.\nAt least a centromere should be detected, add at least one or interrupt the macro.");
					}
					Dialog.addMessage("--- MANUAL CENTROMERES' DETECTION ---\nChoose the \"Multi-point\" tool to modify the centromeres' selections.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
					Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
					Dialog.show();
					while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
					{
						selectWindow("check position relative to SCs");
						close();
					}
					selectImage(id2);
					centromereDetectedBoolean=0;
				}
				while(selectionType==-1)
			}
			getSelectionCoordinates(xpoints, ypoints);
			//Moved or created points coordinates might not be integers but it is convenient that they are: they need to be transformed
			for(k=0;k<lengthOf(xpoints);k++)
			{
				xpoints[k]=round(xpoints[k]);
				ypoints[k]=round(ypoints[k]);
			}		
			modXPoints=Array.copy(xpoints);
			modYPoints=Array.copy(ypoints);
			SCsArray=newArray(lengthOf(xpoints));//It is going to store the SC number in which the centromere is contained, i.e. if the third centromere is contained in the first SC, then SCsArray[2]=1;
			//Next code checks if a point falls over an SC, otherwise it is located over the closest one
			//If a point is equally close to two SCs it will be asigned to the one appearing first in the ROI Managers
			roiManager("Open", imageResultsDir+fs+"synaptonemal_complexes.zip");
			unasignedCounter=0;
			for(k=0;k<lengthOf(xpoints);k++)
			{
				unasigned=true;
				if(unasigned)
				{//checks if the centromere is located inside a SC
					for(l=0;l<nSCs;l++)
					{
						roiManager("select", l);
						if(selectionContains(xpoints[k], ypoints[k]))
						{
							modXPoints[k]=xpoints[k];
							modYPoints[k]=ypoints[k];
							SCsArray[k]=l+1;						
							unasigned=false;	
							//print("The centromere in "+xpoints[k]+", "+ypoints[k]+" is inside the synaptonemal complex "+l+1);			
							l=nSCs;			
						}				
					}
				}
				if(unasigned)//Locates a centromere out of the SCs into the closest SC in a 3x3 matrix. If a centromere is close to different SC, it will be assigned to the SC coming first in the ROI Manager.
				{
					aproximationArrayX=newArray(xpoints[k], xpoints[k]+1, xpoints[k], xpoints[k]-1, xpoints[k]+1, xpoints[k]+1, xpoints[k]-1, xpoints[k]-1, 
						xpoints[k], xpoints[k]+2, xpoints[k], xpoints[k]-2, xpoints[k]+1, xpoints[k]+2, xpoints[k]+2, xpoints[k]+1, xpoints[k]-1, xpoints[k]-2,
						xpoints[k]-2, xpoints[k]-1, xpoints[k]+2, xpoints[k]+2, xpoints[k]-2, xpoints[k]-2);
					aproximationArrayY=newArray(ypoints[k]-1, ypoints[k], ypoints[k]+1, ypoints[k], ypoints[k]-1, ypoints[k]+1, ypoints[k]+1, ypoints[k]-1, 
						ypoints[k]-2, ypoints[k], ypoints[k]+2, ypoints[k], ypoints[k]-2, ypoints[k]-1, ypoints[k]+1, ypoints[k]+2, ypoints[k]+2, ypoints[k]+1,
						ypoints[k]-1, ypoints[k]-2, ypoints[k]-2, ypoints[k]+2, ypoints[k]+2, ypoints[k]-2);
					for(l=0;l<nSCs;l++)
					{
						roiManager("select", l);			
						for(m=0; m<24; m++)
						{
							if(selectionContains(aproximationArrayX[m], aproximationArrayY[m]))
							{
								modXPoints[k]=aproximationArrayX[m];
								modYPoints[k]=aproximationArrayY[m];
								SCsArray[k]=l+1;		
								unasigned=false;	
								//print("The centromere in "+xpoints[k]+", "+ypoints[k]+" turned to "+aproximationArrayX[m]+", "+aproximationArrayY[m]+", which is inside synaptonemal complex "+l+1);
								m=24;
								l=nSCs;															
							}
						}
					}					
				}
				if(unasigned)//The centromere is neither in a SC nor closer than a 3x3 pixel  matrix.
				{
					selectWindow(dirFileListArray[i]);
					unasignedCounter++;
					//print("The centromere in "+xpoints[k]+", "+ypoints[k]+" has not been assigned to any synaptonemal complex or has been manually assigned");
					makePoint(xpoints[k], ypoints[k]);				
					run("Point Tool...", "type=Circle color=Red size=Large counter=0");
					continue1=false;//"continue" cannot be used
					error=false;
					do
					{//This loop can be exited drawing different ROIs as far as the selected one is a point selection. In this situarion, all ROIs but the last one will be ignored
						if(error==false)
						{
							Dialog.createNonBlocking("Synaptonemal & CO analyzer");
							Dialog.addMessage("The centromere at the screen has not been assigned to any synaptonemal complex.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the centromere selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
							Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
							Dialog.show();
							while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
							{
								selectWindow("check position relative to SCs");
								close();
							}
							selectImage(id2);
							//waitForUser("The centromere site at the screen has not been assigned to any synaptonemal complex.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the centromere selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nPress \"OK\" afterwards.");
							}
						else
						{
							Dialog.createNonBlocking("Synaptonemal & CO analyzer");
							Dialog.addMessage("The selection is not a point selection, or it has not been moved nor deleted.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the centromere selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nSelect an image then press \"c\" to open the original image to visualize details in case of doubt.\nPress \"OK\" afterwards.");
							Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
							Dialog.show();
							while(isOpen("check position relative to SCs"))//if the macro checkPositionsRelativeToSCs is executed an image is created that needs to be closed
							{
								selectWindow("check position relative to SCs");
								close();
							}
							selectImage(id2);
							//waitForUser("The selection is not a point selection, or it has not been moved nor deleted.\nDelete it or move it.\nChoose the\"Multi-point\" tool to modify the centromere selection.\nMove selections dragging and dropping.\nLeft click to add selections.\nAlt+left click to delete selections.\nPress \"OK\" afterwards.");
							}
						if(selectionType()==-1)
						{
							//print("The centromere site in:"+ modXPoints[k]+", "+modYPoints[k]+" has been deleted.");
							continue1=true;
						}
						else if(selectionType()==10)
						{
							getSelectionBounds(x, y, width, height);
							xpoints[k]=round(x);
							ypoints[k]=round(y);
							k--;
							continue1=true;
						}
						else{
							//print("The selection is not a point selection, or it has not been moved nor deleted.");
							error=true;
						}
					}
					while(continue1==false)
						
				}
			}
			run("Remove Overlay");//SCs overlay is removed
			//print("The number of CO sites that have not been automatically assigned to a SC is: "+unasignedCounter++);
			//print("xpoints: ");
			//Array.print(xpoints);
			//print("ypoints: ");
			//Array.print(ypoints);
			//print("modXPoints: ");
			//Array.print(modXPoints);
			//print("modYPoints: ");
			//Array.print(modYPoints);
			//print("SCsArray: ");
			//Array.print(SCsArray);
			roiManager("deselect");
			run("Select None");
			roiManager("reset");
			checkCentromeresPerSC();//check whether there is more than a centromere per SC, draws them all and ask the user to keep only one
			nDeletedPoints=0;
			for(k=0; k<lengthOf(modXPoints);k++)
			{
				if(SCsArray[k]==0)
				{
					nDeletedPoints++;
				}
			}
			finalPointsArrayX=newArray(lengthOf(modXPoints)-nDeletedPoints);
			finalPointsArrayY=newArray(lengthOf(modYPoints)-nDeletedPoints);	
			finalPointsArrayIndex=0;		
			for(k=0, l=0; k<lengthOf(modXPoints); k++)
			{
				if(SCsArray[k]!=0)
				{
					finalPointsArrayX[l]=modXPoints[k];
					finalPointsArrayY[l]=modYPoints[k];
					l++;
				}
			}
			//print("finalPointsArrayX: ");
			//Array.print(finalPointsArrayX);
			//print("finalPointsArrayY: ");
			//Array.print(finalPointsArrayY);
			roiManager("reset");
			makeSelection("point", finalPointsArrayX, finalPointsArrayY);
			run("Point Tool...", "type=Circle color=White size=[Extra Large] counter=0");
			resetThreshold();
			setTool("multipoint");
			roiManager("add");
			roiManager("select",0);
			roiManager("rename", "centromeres");
			roiManager("save", imageResultsDir+fs+"centromeres.zip");//save centromeres as a ROI
			run("Colors...", "foreground=white background=black selection=yellow");//In the previous step, changing the color of the selection to white changes the selection color to white for all future selections
			roiManager("show all without labels");
			roiManager("show none");
			run("Hide Overlay");
			roiManager("reset");
			run("Select All");
			setForegroundColor(0, 0, 0);
			run("Fill", "slice");//get a dark image
			run("Select None");
			roiManager("reset");
			roiManager("Open", imageResultsDir+fs+"synaptonemal_complexes.zip");
			setForegroundColor(255, 255, 255);
			roiManager("Fill");//get an image with white SCs over black background
			run("Set Measurements...", "area redirect=None decimal=0");
			roiManager("Measure");
			roiManager("reset");
			roiManager("Open", imageResultsDir+fs+"centromeres.zip");
			roiManager("Select", 0);
			setForegroundColor(0, 0, 0);
			roiManager("Fill");//get an image with white SCs interrupted by centromeres position
			roiManager("reset");
			run("Select None");
			roiManager("Open", imageResultsDir+fs+"synaptonemal_complexes.zip");//open the SCs ROis
			id3=0;//if id3 is set to 0, the starting point will be random from one of the two free sides of the SC
			xStartingPointsArray=newArray(nSCs);
			yStartingPointsArray=newArray(nSCs);
			for(k=0;k<roiManager("count");k++)
			{
				//print("SC-"+k+"-------------");
				var initialX, initialY;
				startingPointArray=startingPoint(id2,k,id3);//get a random starting point from each SC
				//print("startingPointArray: ");
				//Array.print(startingPointArray);
				xStartingPointsArray[k]=startingPointArray[0];
				yStartingPointsArray[k]=startingPointArray[1];
				measure("centromeres",k,xStartingPointsArray[k],yStartingPointsArray[k]);//gets the centromere position relative to the random starting point for each SC
				//selectWindow("SC's length_"+dirFileListArray[i]);
				//Table.update;
			}	
			//Next code saves centromeres as a roiset
			roiManager("reset");
			/*for(k=0;k<nSCs;k++)//creates an arrow selection for each starting point
			{
				if(xStartingPointsArray[k]>10)
				{
					initialArrowX=xStartingPointsArray[k]-10;
				}
				else
				{
					initialArrowX=xStartingPointsArray[k]+10;
				}
				if(yStartingPointsArray[k]>10)
				{
					initialArrowY=yStartingPointsArray[k]-10;
				}
				else
				{
					initialArrowY=yStartingPointsArray[k]+10;
				}
				makeArrow(initialArrowX, initialArrowY, xStartingPointsArray[k], yStartingPointsArray[k], "notched outline");
				roiManager("add");
			}
			for(z=0;z<roiManager("count");z++)
			{
				roiManager("select", z);
				roiManager("rename", "SC starting point-"+z+1);
			}*/
			//if(nucleiSlice!=0)//save centromeres positions or SCs starting points ROIs
			//{roiManager("save", imageResultsDir+fs+"centromeres_positions.zip");}
			//else{roiManager("save", imageResultsDir+fs+"SCs_starting_points.zip");}
			//roiManager("save", imageResultsDir+fs+"centromeres_positions.zip");
			//roiManager("reset");
			//if(nucleiSlice!=0){close();}//close the DAPI channel image if it does exist
			selectImage(id2);
			close();
		}//end of loop for centromere position analysis based on a centromere's probe
		//Next code updates and saves results table
		selectWindow("SC's length_"+dirFileListArray[i]);
		Table.update;
		globalResults();//this function creates results per nuclei and adds them to the results table
		if(centromereSlice>0 && computeAllBoolean)//Next block modifies results table if an analysis of centromeres using a specific centromeres label has been done
		{
			modifyResultsTable();
		}
		Table.save(imageResultsDir+fs+"SC's length_"+dirFileListArray[i]+".txt");
		selectWindow("SC's length_"+dirFileListArray[i]);
		run("Close");
		roiManager("reset");
			
		//next code saves image as RGB, as requested by the user (unless it is a single image, which will keep its original format)
		if(sliceNumber!=1)
		{
			call("ij.gui.ImageWindow.setNextLocation", 0.01*screenWidth, 0.41*screenHeight);
			open(imageResultsDir+fs+replace(imageTitle, fileExtension, ".tif"));
			id7=getImageID();
			run("Duplicate...", "duplicate");
			id5=getImageID();
			run("Make Composite");
			run("Stack to RGB");
			id6=getImageID();
			saveAs("tiff", imageResultsDir+fs+imageTitle);
			selectImage(id7);
			close();
			selectImage(id6);
			close();
			selectImage(id5);
			close();
		}
	
	}////end of loop for each fileExtension image in image's path
}//end of loop for each file in image's path		
exit("The macro is done");
//////////////////////////////////////////////// MACROS AND FUNCTIONS
macro "interrupt [i]"{
	print("\\Clear");//reset the log window
	imagesArray=getList("image.titles");
	for(i=0; i<lengthOf(imagesArray);i++)//close all open images
	{
		selectWindow(imagesArray[i]);
		close();
	}
	if(isOpen("Results"))//close the results window
	{
		selectWindow("Results");
		run("Close");
	}
	roiManager("reset");//reset the ROI manager
	exit("The macro has been interrupted at user's request");
}//end of macro "draw"

macro "draw [d]"{
	selectWindow("SCs BINARY");
	setForegroundColor(255, 255, 255);
	run("Fill", "slice");
}//end of macro "draw"

macro "erase [e]"{
	selectWindow("SCs BINARY");
	setForegroundColor(0, 0, 0);
	run("Fill", "slice");
}//end of macro "erase"

macro "correctOverlap [o]"{
	//numOverlappingSCs=getNumber("¿Cuántos SCs están solapando?", 2);//Creates an error when next waitForUser is called
	//Potential issue: 2 menus with an OK button are created, if they are are not closed in the proper order, the macro won't work correctly. 
	//This macro assumes that the corrected SCs (drawn by the user) do not have branching point. If they have the functions "startingPoint" and "measureSCs" will not work and the macro will stop.
	selectWindow("SCs 8-BIT");
	if(selectionType() != -1)
	{
		selectWindow("SCs 8-BIT");
		run("Select None");
	}
	selectWindow("SCs BINARY");
	if(selectionType() != -1)
	{
		selectWindow("SCs BINARY");
		run("Select None");
	}
	selectWindow("SCs BINARY");
	setTool("polygon");
	Dialog.createNonBlocking("Overlap correction");
	Dialog.addNumber("How many overlaps are there?", 2);
	Dialog.addMessage("Create a selection on the binary image containing the overlapping SC's\nPress \"OK\" afterwards.");
	Dialog.show();
	numOverlappingSCs=Dialog.getNumber();
	selectWindow("SCs BINARY");
	while(selectionType()== -1||selectionType()>4)//Make sure the user has made a selection on the "SCs BINARY", using the rectangle, oval, polygon or freehand tools
	{
		Dialog.createNonBlocking("Overlap correction");
		Dialog.addMessage("No selection has been made on the binary image or it is not valid.\nCreate a selection using the \"Rectangle\", \"Oval\", \"Polygon\" o \"Freehand Selection\" tools.\nPress \"OK\" afterwards.");
		Dialog.show();
		selectWindow("SCs BINARY");
	}
	run("Copy");
	roiManager("add");
	roiIndex=roiManager("count")-1;
	run("Select None");
	selectWindow("SCs 8-BIT");
	run("Select None");
	selectWindow("SCs BINARY");
	setTool("polyline");
	setForegroundColor(255,255,255);
	for(l=1;l<=numOverlappingSCs; l++)
	{
		roiManager("show none");
		Dialog.createNonBlocking("Overlap correction");
		if(l==1)
		{Dialog.addMessage("Modify a SC using the draw (d) and erase (e) tools.\nPress \"OK\" afterwards.");}
		else
		{Dialog.addMessage("Modify next SC using the draw (d) and erase (e) tools.\nPress \"OK\" afterwards.");}
		Dialog.show();
		selectWindow("SCs BINARY");
		run("Skeletonize");//This skeletonize ensures that drawn SCs are squeletons,otherwise the function "measure" might not work properly.
		roiManager("select", roiIndex);
		run("Analyze Particles...", "pixel add");
		roiManager("select",roiManager("count")-1);
		roiManager("rename", "overlap");
		if(l!=numOverlappingSCs)
		{
			selectWindow("SCs BINARY");
			roiManager("select", roiIndex);
			run("Paste");
		}
		else {
			selectWindow("SCs BINARY");
			roiManager("select", roiIndex);
			setForegroundColor(0, 0, 0);
			run("Fill", "slice");
		}
		roiManager("deselect");
		run("Select None");
		roiManager("show none");
	}
	roiManager("select", roiIndex);
	roiManager("delete");
	selectWindow("SCs 8-BIT");
	run("Select None");
	selectWindow("SCs BINARY");
	run("Select None");
}//end of macro "correctOverlap"
/*
 * This macro should be used during the COs and centromeres detection step, if any of them could not be asign to an SC, to open an SC image and 
 * overlay the selection of the unasigned object. The overlay should not be selectable.
 * In order for this macro to work properly, last opened image before executing it needs to be the SCs image.
 */
macro "checkPositionsRelativeToSCs [c]"{
	imageTitlesArray=getList("image.titles");
	//Array.print(imageTitlesArray);
	if(lengthOf(imageTitlesArray)!= 1)
	{
		waitForUser("Check position relative to SC macro","No image or more than an image are open while only one is expected");
	}
	else{
		lastOpenedImageDir=File.directory;
		//lastOpenedImageDir=File.directory;
		lastOpenedImageName=File.name;
		//print(lastOpenedImageDir);
		//print(File.name);
		open(lastOpenedImageDir+lastOpenedImageName);//opens last opened image
		rename("check position relative to SCs");
		selectWindow(imageTitlesArray[0]);
		if(selectionType()!=-1)
		{
			roiManager("add");
		}
		selectWindow("check position relative to SCs");
		roiManager("select",roiManager("count")-1);
		Overlay.addSelection;
		Overlay.selectable(false);
		roiManager("select",roiManager("count")-1);
		roiManager("delete");
		run("Select None");

	}
}//end of macro checkCOs 
function startingPoint(imageID,roiIndex,dnaImageID){
/*
 * This function locates the starting coordinate of a linear ROI (non-branching ROI) in the ROI Manager. 
 * The starting coordinate can either:
 * 	1- be selected at random amongst the two final coordinates of the ROI (if id3 is set to 0) 
 * 	2- be selected amongst the two final coordinates of the ROI as the one with the highest intensity in the blue channel (if id3 is set to a blue channel image). 
 * 	This i so because SC´s are bound to the DNA in the centromere end in sperma images.
 * Important: the function assumes linear ROIs with no branching points nor 90º end points. Both will be interpreted as a branching point, an error delivered and 
 * the macro interrupted.
 * Inputs:- imageId: the identitiy of the image in which the ROI is located. This image has to be binary. 1-> ROI content, 0-> otherwise.
 *        - roiIndex: the index in the ROI Manager of the ROI to analyze 
 *        - dnaImageId: values, the identity of the image in which the intensity is going to be measured or 0 if no intensity measurements are going to be done.
 * Output: - startingPointsArray. An array of two elements, containing the starting point x an y coordinates.       
 */
 	startingPointsArray=newArray(2);//Output of the function
 	selectImage(imageID);
 	roiManager("select",roiIndex);
	Roi.getContainedPoints(xpoints, ypoints);
	//print("xpoints: ");
	//Array.print(xpoints);
	//print("ypoints: ");
	//Array.print(ypoints);
	neighboursArray=newArray(lengthOf(xpoints));
	xArray=newArray(-1, 0, 1, 1, 1, 0, -1, -1);
	yArray=newArray(-1, -1, -1, 0, 1, 1, 1, 0);
	for(i=0;i<lengthOf(xpoints);i++)
	{
		neighbours=0;
		x=xpoints[i];
		y=ypoints[i];
		for(j=0; j<lengthOf(xArray);j++)
		{
			if(Roi.contains(x+xArray[j], y+yArray[j]))
			{
				neighbours++;
			}		
		}
		neighboursArray[i]=neighbours;
	}
	//print("neighboursArray: ");
	//Array.print(neighboursArray);
	xFinalPointsArray=newArray(2);
	yFinalPointsArray=newArray(2);
	finalPointsCounter=0;
	for(i=0;i<lengthOf(neighboursArray);i++)
	{
		if(neighboursArray[i]==1)
		{
			if(finalPointsCounter>1)
			{
				selectImage(imageID);
				exit("The SC in the screen has at least one branch.\nThis macro assumes non-branching SCs.\n The macro will stop.\nRun the macro again carefully thresholding SCs.");
			}
			xFinalPointsArray[finalPointsCounter]=xpoints[i];
			yFinalPointsArray[finalPointsCounter]=ypoints[i];
			//print("The ROI begins or ends at : "+xpoints[i]+", "+ypoints[i]);
			//print("The ROI begins or ends at: "+xFinalPointsArray[finalPointsCounter]+", "+yFinalPointsArray[finalPointsCounter]);
			finalPointsCounter++;
			if(dnaImageID==0)
			{
				startingPointsArray[0]=xFinalPointsArray[0];
				startingPointsArray[1]=yFinalPointsArray[0];
				return startingPointsArray;
			}
		}
	}
	x1=xFinalPointsArray[0];
	x2=xFinalPointsArray[1];
	y1=yFinalPointsArray[0];
	y2=yFinalPointsArray[1];
	selectImage(dnaImageID);
	makeOval(x1-8, y1-8, 16, 16);
	mean1=getValue("Mean");
	makeOval(x2-8, y2-8, 16, 16);
	mean2=getValue("Mean");
	if(mean1>mean2)
	{
		initialX=x1;
		initialY=y1;
		//print("The average intensity of a 16 pixel width oval on coordinate x="+x1+", y="+y1+", is "+mean1+", which is > than "+mean2+" (oval on x="+x2+", y="+y2+")");
	}
	if(mean1<mean2)
	{
		initialX=x2;
		initialY=y2;
		//print("The average intensity of a 16 pixel width oval on coordinate x="+x1+", y="+y1+", is "+mean1+", which is < than "+mean2+" (oval on x="+x2+", y="+y2+")");
	}
	if(mean1==mean2)//consider telling the user if this condition is met
	{
		initialX=x1;
		initialY=y1;
		//print("The average intensity of a 16 pixel width oval on coordinate x="+x1+", y="+y1+", is "+mean1+", which is = than "+mean2+" (oval on x="+x2+", y="+y2+")");
	}
	run("Select None");
	selectImage(imageID);
	roiManager("select", roiIndex);
	startingPointsArray[0]=initialX;
	startingPointsArray[1]=initialY;
	return startingPointsArray;
}//end of startingPoint function

function measure(object,roiIndex,initialX,initialY){
/*
 * This function has been modified from measureSCs(roiIndex,initialX,initialY).
 *This function measures SCs' length and the partial length of each SC between CO sites (if object=COs) or centromere's position (if object=centromeres).
 * Works on images that are white for SCs, black for CO sites or centomerer's position and have SCs selections in the ROI Manager.
 * An SCs ROIS must have been previoulsy selected. The macro counts the number of white pixels, re-starts counting when finding a CO site black pixel or stops counting when finding a centromere black pixel. 
 * The macro takes into account pixel connectivity (whether adjoint pixels touch on one side or on a corner).
 * This function assumes square pixels (pixelWidhth==pixelHeight) and skeletonized SCs. A most robust function would check current position against the matrix of all previous points (not only the last previous point).
 * The distance to the medium of the black pixel is given. If a black pixel falls in the first pixel, the distance value is pixelWidth/2
 * This macro assumes no branching points nor 90º turns (enters an infinity loop in the last case) and that there are not two adjacent dark pixels.
 * Dark pixels are CO or centromere's center of mass positions. Distance is computed to the center of the pixel, so the distance to a black pixel on the first pixel (assuming pixel size=1 and by side touching pixels) is 0.5.
 * INPUT= - object: SCs, COs or centromeres
 *		  - roiIndex (as a parameter): the index of every ROI in the ROI manager.
 * 		  - initialX: the x coordinate of a final point in a SC's ROI (counting will start here)
 * 		  - initialY: the y coodrinate of a final point in a SC's ROI (counting will start here)
 * OUTPUT= printed in a Table named "SC's length_"+the name of the picture file being analyzed.
 * It is assumed that the number of centromeres is either 0 or 1.
 */
SCName=call("ij.plugin.frame.RoiManager.getName", roiIndex);
selectWindow("SC's length_"+dirFileListArray[i]);
if(object=="SCs" || object=="COs")
{
	Table.set("---SC---", roiIndex, SCName);//The macro runs first for SCs, then COs and finally centromeres
	if(roiIndex==0)
	{
		Table.set("Total length", 0, 0);//Total length is set only once per image
		if(computeAllBoolean==1)
		{
			Table.set("COs number", 0, 0);//COs number header is only set if a COs analysis is done
		}
	}
}

/*if(roiIndex==0 && object=="centromeres")
{
	Table.set("Centromere position", roiIndex, 0);
}*/	
nCOs=0;//This variable is going to contain the number of COs on each SC (or the number of centromeres if object=centromeres)
partialLengthCounter=0;
partialLength=0;
totalLength=0;
//xArray and yArray contain the relative coordinates of the 8 possible neighbour pixels
xArray=newArray(-1, 0, 1, 1, 1, 0, -1, -1);
yArray=newArray(-1, -1, -1, 0, 1, 1, 1, 0);
previousX= NaN;
previousY= NaN;
singlePixel=true;
firstPixel=true;
var pixelVicinity;//value equals 8 if next pixel is diagonal, 4 if not
continue2=true;//changes to false when there is NOT a neighbouring pixel, different to the previous one, inside the selection
do{//repeat until there is not a neighbouring pixel inside the selection
	pixelAsignment=false;//true if there is a pixel inside the selection, in the 8 pixel vicinity that is not the previous one
	for(j=0; j<lengthOf(xArray);j++)
	{
		//print("********************************************************************************************************");
		//print("initialX: "+initialX+", initialY: "+initialY);//starting point pixel position
		//print("initialX+xArray["+j+"]: "+initialX+xArray[j]);//x clockwise pixel position relative to the SC
		//print("initialY+yArray["+j+"]: "+initialY+yArray[j]);//y clockwise pixel position  relative to the SC
		//print("previousX= "+previousX+", previousY: "+previousY);
		if(selectionType==-1)
		{
		selectImage(id2);
		}
		if(selectionContains(initialX+xArray[j], initialY+yArray[j]) && (previousX != (initialX+xArray[j]) || previousY != (initialY+yArray[j])))//There is a pixel inside the selection, in the 8 pixel vicinity that is not the previous one
		{
			pixelAsignment=true;
			singlePixel=false;
			if(j==0||j==2||j==4||j==6)//next pixel is diagonal (pixel vicinity = 8)
			{
				pixelVicinity=8;
				//print("pixel vicinity==8 =========================");
				//totalLength=totalLength+sqrt(2)*pixelWidth;//pixel diagonal, as measured by the Pythagoras' theorem
				if(firstPixel==true)
				{
					totalLength=totalLength+sqrt(2)*pixelWidth*1.5;
					//print("THIS IS THE FIRST PIXEL");
					if(getPixel(initialX, initialY)==0)//First pixel is black
					{
						nCOs++;
						//print("FIRST PIXEL IS BLACK");
						//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
						partialLength=partialLength+sqrt(2)*pixelWidth/2;
						//print("sqrt(2)*pixelWidth/2: "+sqrt(2)*pixelWidth/2+", parialLenght: "+partialLength);
						partialLengthCounter++;
						if(object=="centromeres")
						{
							Table.set("Centromere position", roiIndex, toString(partialLength));
							return;//We assume that there is only one centromere per SC
						}
						if(object=="COs")//Partial lenghts do only make sense if COs are present
						{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
						Table.update;
						partialLength=sqrt(2)*pixelWidth;//distance between two pixel centers if 8 pixel vicinity
					}
					else{//First pixel is white
						//print("FIRST PIXEL IS WHITE");
						//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
						partialLength=partialLength+sqrt(2)*pixelWidth*1.5;
						//print("sqrt(2)*pixelWidth*1.5: "+sqrt(2)*pixelWidth*1.5+", parialLenght: "+partialLength);
						//partialLengthCounter++;
						if(getPixel(initialX+xArray[j], initialY+yArray[j])==0)
						{
							//print("SECOND PIXEL IS BLACK");
							nCOs++;
							partialLengthCounter++;
							if(object=="centromeres")
							{
								Table.set("Centromere position", roiIndex, toString(partialLength));
								return;
							}
							if(object=="COs")
							{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
							Table.update;
							partialLength=0;
						}						
					}
				}
				else if(getPixel(initialX+xArray[j], initialY+yArray[j])==0)//next pixel is black
				{
					//print("NEXT PIXEL IS BLACK");
					//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
					nCOs++;
					partialLengthCounter++;
					partialLength=partialLength+sqrt(2)*pixelWidth;//diagonal is added to partial lenght
					if(object=="centromeres")
					{
						Table.set("Centromere position", roiIndex, toString(partialLength));
						return;
					}
					if(object=="COs")
					{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
					partialLength=0;
					totalLength=totalLength+sqrt(2)*pixelWidth;
				}
				else{//next pixel is not black
					//print("NEX PIXEL IS NOT BLACK");
					partialLength=partialLength+sqrt(2)*pixelWidth;//pixel diagonal, as measured by the Pythagoras' theorem
					totalLength=totalLength+sqrt(2)*pixelWidth;
				}
				previousX=initialX;
				previousY=initialY;
				initialX=initialX+xArray[j];
				initialY=initialY+yArray[j];
			}
			if(j==1||j==3||j==5||j==7)//pixel vicinity = 4
			{
				pixelVicinity=4;
				//print("pixel vicinity==4 =========================");
				if(firstPixel==true)
				{
					totalLength=totalLength+pixelWidth*1.5;//A pixel and a half is added to the total length					
					//print("THIS IS THE FIRST PIXEL");
					if(getPixel(initialX, initialY)==0)//First pixel is black
					{
						nCOs++;
						//print("first PIXEL IS BLACK");
						//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
						partialLength=partialLength+pixelWidth/2;
						//print("pixelWidth/2: "+pixelWidth/2+", parialLenght: "+partialLength);
						partialLengthCounter++;
						if(object=="centromeres")
						{
							Table.set("Centromere position", roiIndex, toString(partialLength));
							return;
						}
						if(object=="COs")
						{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
						Table.update;
						partialLength=pixelWidth;//distance between two pixel centers if pixel vicinity=4
					}
					else {//first pixel is white
						//print("FIRST PIXEL IS WHITE");
						//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
						partialLength=partialLength+pixelWidth*1.5;
						//print("pixelWidth*1.5: "+pixelWidth*1.5+", parialLenght: "+partialLength);
						if(getPixel(initialX+xArray[j], initialY+yArray[j])==0)
						{
							//print("SECOND PIXEL IS BLACK");
							nCOs++;
							partialLengthCounter++;
						if(object=="centromeres")
						{
							Table.set("Centromere position", roiIndex, toString(partialLength));
							return;
						}	
						if(object=="COs")
						{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
							Table.update;
							partialLength=0;
						}		
					}
				}
				else if(getPixel(initialX+xArray[j], initialY+yArray[j])==0)//next pixel is black
				{
					totalLength=totalLength+pixelWidth;
					//print("NEXT PIXEL IS BLACK");
					//print("initialX+xArray["+j+"]: "+initialX+xArray[j]+", initialY+yArray["+j+"]:"+initialY+yArray[j]);
					nCOs++;
					partialLength=partialLength+pixelWidth;
					//print("pixelWidth: "+pixelWidth+", parialLenght: "+partialLength);
					partialLengthCounter++;
					if(object=="centromeres")
					{
						Table.set("Centromere position", roiIndex, toString(partialLength));
						return;
					}
					if(object=="COs")
					{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
					Table.update;
					partialLength=0;
				}
				else{//next pixel is not black
					partialLength=partialLength+pixelWidth;//pixel side size
					totalLength=totalLength+pixelWidth;
				}
				previousX=initialX;
				previousY=initialY;
				initialX=initialX+xArray[j];
				initialY=initialY+yArray[j];
			}	
			j=8;//breaks the loop for that looks for neighbouring pixels inside the selection
			firstPixel=false;
		}
	}
if(pixelAsignment==false)//There is NOT a pixel inside the selection, in the 8 pixel vicinity that is not the previous one
		{
			//print("**************178*************");
			continue2=false;
			if(singlePixel)//This a single pixel selection
			{
				//print("THIS IS A SINGLE PIXEL SELECTION");
				partialLength=pixelWidth;//If there is a CO site in the first pixel of the SC, the value of its location won't be 0 but l/2
				totalLength=pixelWidth;//If there is a CO site in the first pixel of the SC, the value of its location won't be 0 but l/2
				if(object=="centromeres")
				{
					Table.set("Centromere position", roiIndex, toString(partialLength));
					return;
				}
				if(object=="COs")
				{Table.set("Partial length-"+partialLengthCounter+1, roiIndex, toString(partialLength));}
			}
			else//This is the last pixel in the selection
			{
				partialLengthCounter++;
				//print("************************190*****************");
				if(pixelVicinity==4)
				{
					//print("pixelVicinity==4");
					partialLength=partialLength+0.5*pixelWidth;
					totalLength=totalLength+0.5*pixelWidth;
					}
				if(pixelVicinity==8)
				{
					//print("pixelVicinity==8");
					partialLength=partialLength+0.5*sqrt(2)*pixelWidth;
					totalLength=totalLength+0.5*sqrt(2)*pixelWidth;
					}
				if(object=="centromeres")
				{
					//Table.set("Centromere position", roiIndex, toString(partialLength));
					Table.set("Centromere position", roiIndex, 0);
					return;
				}
				if(object=="COs")
				{Table.set("Partial length-"+partialLengthCounter, roiIndex, toString(partialLength));}
			}
		}
}
while(continue2)
//print("totalLength: "+totalLength);
Table.set("Total length", roiIndex, toString(totalLength));
if(computeAllBoolean==1)
{
	Table.set("COs number", roiIndex, toString(nCOs));
}
}//end of function measure(object,roiIndex,initialX,initialY)

/*		
 * This function is meant to delete all slices in a stack but one containing COs, SCs, nuclei or centromeres.
 * The slice to keep is introduced in the parameter slice, in the macro it is stored in the variables: COsSlice, SCsSlice, centromereSlice or nucleiSlice.
 * E.g.: COsSlice=1 means that the first slice in the image stack contains COs.
 */		
function selectSlice(slice){
	if(nSlices!=1)
	{
		originalNSlices=nSlices;
		toKeepSlice=slice;
		deletedSlices=0;
		for(p=1;p<=originalNSlices;p++)
		{
			setSlice(p-deletedSlices);
			if(p-deletedSlices!=toKeepSlice)
			{
				run("Delete Slice", "delete=channel");
				deletedSlices++;
				toKeepSlice--;
			}
		}
	}			
}//end of function selectSlice(slice)
function globalResults(){
		//Next code modifies the results table. It sums Totallenght and COs number values, adds a final SUM row and fills it with such values (rest of columns are filled with ---) 
		//Trying to get rid of the table row numbers with Table.showRowIndexes(false) and Table.showRowNumbers(false), causes this code to produce to mismach columns
		computeTotalLength=false;
		computeTotalCO=false;
		headingsArray=split(Table.headings,"\t");
		for(i=1;i<lengthOf(headingsArray);i++)//Starts with 1 because headingsArray first element is empty and creates a new column with no name at the end of the table
		{
			if(headingsArray[i]=="Total length")
			{
				computeTotalLength=true;
			}
			if(headingsArray[i]=="COs number")
			{
				computeTotalCO=true;
			}
		}	
		if(computeTotalLength){sumSCLength=0;}
		if(computeTotalCO){sumCONumber=0;}
		for(i=0;i<Table.size;i++)
		{
			if(computeTotalLength)
			{
				sumSCLength=sumSCLength+Table.get("Total length", i);
				//print("sumSCLenght:" +sumSCLength);	
			}
			if(computeTotalCO){sumCONumber=sumCONumber+Table.get("COs number", i);}
		}
		lastRow=Table.size;
		Table.set("---SC---",lastRow,"SUM");
		if(computeTotalLength){Table.set("Total length",lastRow,sumSCLength);}
		if(computeTotalCO){Table.set("COs number",lastRow,sumCONumber);}
		//headingsArray=split(Table.headings,"\t");
		for(i=1;i<lengthOf(headingsArray);i++)//Starts with 1 because headingsArray first element is empty and creates a new column with no name at the end of the table
		{
			//print(i);
			//print(headingsArray[i]);
			if(headingsArray[i]!="---SC---" && headingsArray[i]!="Total length" && headingsArray[i]!="COs number")
			{
				Table.set(headingsArray[i], lastRow, "----");
			}
		
		}
		Table.update;
}//end of funcion globalResults();
function CO_analysis(){
	/*
	 * Function created to ease macro adaptation to different experimental conditions
	 * This function asks the user to draw selections over the SCs' background in the CO image. The mean and standard deviation of the pixels
	 * in such selections is computed and the value of the mean plus 2 standard deviations is set as a threshold. Any object brighter than the 
	 * threshold and bigger than 10 pixels is considered a CO and its center of mass computed.
	 * This function can be comented/erased and substituted by any code as far as the result is a results table containing COs' centers of mass. 
	 * Such table should equal the ones that imageJ creates when analyzing particles: it should contain detected COs in rows, and X and Y centers 
	 * of mass coordinates in two columns entitled XM and YM. The easiest way to create this table is by performing a center of mass analysis in 
	 * imageJ.
	  */
	
	setTool("polygon");
	Dialog.createNonBlocking("Synaptonemal & CO analyzer");
	Dialog.addMessage("Create some selections over the SCs background.\nPress \"OK\" afterwards.");
	Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
	Dialog.show();		
	mean=getValue("Mean");//gets the mean grey value of the pixels in the selection
	stdDev=getValue("StdDev");//gets the standard deviation of the mean grey value of the pixels in the selection
	threshold=floor(mean+2*stdDev);
	//print("mean: "+mean+", stdDev: "+stdDev+", threshold: "+threshold);
	setThreshold(threshold, 255);
	run("Select None");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");//All measures have to be in pixels. They can be converted into microns afterwards.
	run("Set Measurements...", "center limit redirect=None decimal=0");
	run("Analyze Particles...", "size=10-Infinity display clear include");//objects smaller than 10 pixels are excluded from the analysis
}//end of function CO_analysis
function centromere_analysis(){
	/*
	 * This function is copied from CO_analysis.
	 * Function created to ease macro adaptation to different experimental conditions
	 * This function asks the user to draw selections over the centromeres' background in the centromeres' image. The mean and standard deviation of the pixels
	 * in such selections is computed and the value of the mean plus 2 standard deviations is set as a threshold. Any object brighter than the 
	 * threshold and bigger than 10 pixels is considered a centromere and its center of mass computed.
	 * This function can be comented/erased and substituted by any code as far as the result is a results table containing centromeres' centers of mass. 
	 * Such table should equal the ones that imageJ creates when analyzing particles: it should contain detected centromeres in rows, and X and Y centers 
	 * of mass coordinates in two columns entitled XM and YM. The easiest way to create this table is by performing a center of mass analysis in 
	 * imageJ.
	  */
	
	setTool("polygon");
	Dialog.createNonBlocking("Synaptonemal & CO analyzer");
	Dialog.addMessage("Create some selections over the centromeres' background.\nPress \"OK\" afterwards.");
	Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
	Dialog.show();		
	mean=getValue("Mean");//gets the mean grey value of the pixels in the selection
	stdDev=getValue("StdDev");//gets the standard deviation of the mean grey value of the pixels in the selection
	threshold=floor(mean+2*stdDev);
	//print("mean: "+mean+", stdDev: "+stdDev+", threshold: "+threshold);
	setThreshold(threshold, 255);
	run("Select None");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");//All measures have to be in pixels. They can be converted into microns afterwards.
	run("Set Measurements...", "center limit redirect=None decimal=0");
	run("Analyze Particles...", "size=10-Infinity display clear include");//objects smaller than 10 pixels are excluded from the analysis
}//end of function centromere_analysis
function SC_analysis(){
	/*
	 * Function created to ease macro adaptation to different experimental conditions
	 * This function performs some processing steps aimed at easing thresholding, asks the user to threshold the SCs, performs a reconstruction
	 * step to get rid of small particles, and finally performs some processing steps aimed at easing skeletonizing. 
	 * This function can be comented/erased and substituted by any code as far as the result is a binary image with white objects containing the
	 * skeletons of the SCs
	  */
		run("Subtract Background...", "rolling=6");//background substraction step
		run("Threshold...");
		run("Grays");
		run("Gaussian Blur...", "sigma=1");//Get rid of irregular outlines to facilitate skeletonize (the macro does not proccess SC that fork)
		Dialog.createNonBlocking("Synaptonemal & CO analyzer");
		Dialog.addMessage("Threshold the synaptonemal complexes.\nDo not apply the threshold.\nPress \"OK\" afterwards.");
		Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
		Dialog.show();
		run("Convert to Mask");
		run("BinaryFilterReconstruct ", "erosions=2 white");//Get rid of small objects without affecting SCs shape
		run("Close-");//Get rid of irregular outlines to facilitate skeletonize (the macro does not proccess SC that fork)
		run("Open");//Get rid of irregular outlines to facilitate skeletonize (the macro does not proccess SC that fork)
		run("Skeletonize");
}//end of function SC_analysis
function modifyResultsTable()
{
/*
 * This function is going to create a results table for SC analysis for chromosomes that are not telocentric.
 * This function is going to:
 * 1- compute the distances of each COs relative to the centromere as whell as the distance from the last COs to the end of the SC.
 * 2- compute the number of COs per each SC arm.
 * It works on a results table containing SC-name, Total lenght, COs number, Partial length 1, Partial lenght 2, ..., Centromere position.
 * pl= partial length
 * The code below will only execute if the header "Centromere position" !=0 (no need to modify results if no centromeres)
 * In order to achieve the first goal:
 * 	1.1- get a Partial length Array from the table: partialLengthArray
 * 	1.2- get the centromere position from the table
 * 	1.3- get the COs number from the table
 * 	1.4- creat newPartialLengthArray, size= partialLenghtArraySize+1
 * 	1.5-
 * 		firstArmCOs=0;secondArmCOs=0;
 * 		sum=0
 * 		sumDelayed=0
 * 		for each element in partialLengthArray
 * 		sum=sum+value of partialLengthArray
 * 		if (i==0) if sum > centromere position: the centromere is at one extrem of the SC: partialLengthArray==newPartialLengthArray: DO NOTHING AT ALL
 * 		if sum < centromere Position: newPartiallenthArrayValue= - partialLenghtArrayValue (the minus indicates we are on a side of the SC)
 * 		firstArmCOs++;
 * 		if sum > centromere Position: value newPartialLengthArrayValue= - (centromere position -sumDelayed)
 * 									: next value newPartialArrayValue= sum-centromere position
 * 									break and fill the rest of newPartialArrayValue with the values from partialLengthArrayValue
 * 									secondArmCOs=(COs numbers)-firstArmCOs
 * 		sumDelayed=sum+value of partialLengthArray
 * 	1.6 change the array with the new data
 */
 var totalNewPartialLengthArray=newArray(0); //needed on step 1.6
 var totalArmNewPartialLengthArray=newArray(0); //needed on step 1.6
 var totalRowArmNewPartialLengthArray=newArray(0); //needed on step 1.6
 var maxArm1PartialLengthCounter=0;//needed on step 1.6
 var  maxArm2PartialLengthCounter=0;//needed on step 1.6
 //print(Table.size);
 headersString=Table.headings;
 //print(headersString);
 headersArray=split(headersString,"\t");
 lengthOf(headersArray);
 for(i=0;i<lengthOf(headersArray);i++)//The first header is blank
 {
 	//print(headersArray[i]);
 }
 //print("Table size: "+Table.size);
 fillingArrayIndex=0;
 for(i=0;i<Table.size-1;i++)//loop for each row in the table but the last one (it is not used since it contains a sumatori)
 {
 	if(Table.get("Centromere position",i)!=0)
 	{
	 	//1.1 begins
	 	//print("--------------row: "+i+" ------------------------");
	 	partialLengthArraySize=0;
	 	 for(j=0;j<lengthOf(headersArray);j++)//This code is computing the size of endsAndCOsPositionsArray for this row
		 {
		 	//print(headersArray[j]);
		 	if(startsWith(headersArray[j],"Partial") && Table.get(headersArray[j],i)>0)
		 	{
		 		//print(headersArray[j]+" starts with Partial length");
		 		partialLengthArraySize++;
		 	}
		 }
		 //print("partialLengthArraySize: "+partialLengthArraySize);
		 partialLengthArray=newArray(partialLengthArraySize);
		fillingArrayIndex=0;
	 	 sum=0;
	 	 for(j=0;j<lengthOf(headersArray);j++)
		 {
		 	//print(headersArray[j]);
		 	if(startsWith(headersArray[j],"Partial")&& Table.get(headersArray[j],i)>0)
		 	{
		 		//print(headersArray[j]+" starts with Partial length");
		 		partialLengthArray[fillingArrayIndex]=Table.get(headersArray[j],i);
		 		fillingArrayIndex++;
		 	}	 	
		 }
		// print("partialLengthArray: ");
		//Array.print(partialLengthArray);
		 //1.1 ends
		 //1.2 begins
		 centromerePosition=Table.get("Centromere position",i);
		//print("centromerePosition: "+centromerePosition);
		 //1.2 ends
		 //1.3 begins
		 COsNumbers=Table.get("COs number",i);
		 //print("COS number: "+COsNumbers);
		 //1.3 ends	 
	 	//1.4 begins
	 	newPartialLengthArray=newArray(partialLengthArraySize+1);
	 	fillingArrayIndex=0;
	 	//1.4 ends
	 	//1.5 begins
	 	firstArmCOs=0;
	 	secondArmCOs=0;
	 	sum=0;
	 	sumDelayed=0;
	 	for(j=0;j<lengthOf(partialLengthArray);j++)
	 	{
	 		sum=sum+partialLengthArray[j];
				//print("j: "+j);
	 			//print("sum:"+sum+", centromere position: "+centromerePosition+", sumDelayed: "+sumDelayed);
	 			if(sum<centromerePosition)
	 			{	
	 				//print("sum<centromere position");
	 				newPartialLengthArray[fillingArrayIndex]=-partialLengthArray[j];//the minus indicates we are on a side of the SC
	 				//print("newPartialLenghtArray["+fillingArrayIndex+"]="+-partialLengthArray[j]);
	 				fillingArrayIndex++;
	 				firstArmCOs++;
	 				sumDelayed=sumDelayed+partialLengthArray[j];	
	 			}
	 			
				if(sum>centromerePosition)
				{
					//print("sum>cetromere position");
					if(j==0)
					{
						//print("j("+j+")=0");
						newPartialLengthArray[fillingArrayIndex]=-centromerePosition;
						//print("newPartialLenghtArray["+fillingArrayIndex+"]="+-centromerePosition);
						fillingArrayIndex++;
						newPartialLengthArray[fillingArrayIndex]=sum-centromerePosition;
						//print("newPartialLenghtArray["+fillingArrayIndex+"]="+sum-centromerePosition);
						fillingArrayIndex++;
					}
					else
					{
						//print("j("+j+")!=0");
						newPartialLengthArray[fillingArrayIndex]=-(centromerePosition-sumDelayed);
						//print("newPartialLenghtArray["+fillingArrayIndex+"]="+-(centromerePosition-sumDelayed));
						fillingArrayIndex++;
						newPartialLengthArray[fillingArrayIndex]=sum-centromerePosition;
						//print("newPartialLenghtArray["+fillingArrayIndex+"]="+sum-centromerePosition);
						fillingArrayIndex++;
					}
				sumDelayed=sumDelayed+partialLengthArray[j];	
					for(k=fillingArrayIndex;k<lengthOf(newPartialLengthArray);k++)
					{
						newPartialLengthArray[k]=partialLengthArray[k-1];
					}
					j=lengthOf(newPartialLengthArray);
				}
	
	 		}
	
	 	
	 //print("newPartialLengthArray: ");
	//Array.print(newPartialLengthArray);
	//print("firstArmCOs: "+firstArmCOs);
	//print("COsNumbers: "+COsNumbers);
	 secondArmCOs=COsNumbers-firstArmCOs;
	//print("secondArmCOs: "+secondArmCOs);
	 //1.5 ends
	 //1.6 begins
	 //Table.set(columnName, rowIndex, value);
	 Table.set("CO number arm 1", i, firstArmCOs);
	 Table.set("CO number arm 2", i, secondArmCOs);
	 Table.update; 
	 if(i==0)//fill totalNewPartialLengthArray
	 {
	 	for(j=0;j<lengthOf(newPartialLengthArray);j++)
	 	{
	 		totalNewPartialLengthArray[j]=newPartialLengthArray[j];
	 	}
	 }
	 else//fill totalNewPartialLengthArray
	 {
	 	totalNewPartialLengthArray=Array.concat(totalNewPartialLengthArray,newPartialLengthArray);
	 }
	// fill totalArmNewPartialLengthArray
	 arm1PartialLengthCounter=1;
	 arm2PartialLengthCounter=1;
	 armNewPartialLenghtArray=newArray(lengthOf(newPartialLengthArray));
	 rowArmNewPartialLengthArray=newArray(lengthOf(newPartialLengthArray));
	 for(j=0;j<lengthOf(newPartialLengthArray);j++)
	 {
	 	if(startsWith(newPartialLengthArray[j], "-"))
	 	{
	 		armNewPartialLenghtArray[j]="arm1: partial length"+arm1PartialLengthCounter;
	 		arm1PartialLengthCounter++;
	 		if(arm1PartialLengthCounter>maxArm1PartialLengthCounter)
	 		{
	 			maxArm1PartialLengthCounter=arm1PartialLengthCounter;
	 		}
	 	}
	 	else if(!startsWith(newPartialLengthArray[j], "-"))
	 	{
	 		armNewPartialLenghtArray[j]="arm2: partial length"+arm2PartialLengthCounter;
	 		arm2PartialLengthCounter++;
	 		if(arm1PartialLengthCounter>maxArm1PartialLengthCounter)
	 		{
	 			maxArm1PartialLengthCounter=arm1PartialLengthCounter;
	 		}
	 	}
	 	rowArmNewPartialLengthArray[j]=i;
	 }
	 totalArmNewPartialLengthArray=Array.concat(totalArmNewPartialLengthArray,armNewPartialLenghtArray);
	 totalRowArmNewPartialLengthArray=Array.concat(totalRowArmNewPartialLengthArray,rowArmNewPartialLengthArray);
	 }
 }// end of loop for each row in the table but the last one (it is not used since it contains a sumatori)
 //print("totalNewPartialLengthArray: ");
 //Array.print(totalNewPartialLengthArray);
 //print("totalArmNewPartialLengthArray: ");
 //Array.print(totalArmNewPartialLengthArray);
 //print("totalRowArmNewPartialLengthArray: ");
 //Array.print(totalRowArmNewPartialLengthArray);
 for(i=1;i<=maxArm1PartialLengthCounter;i++)
 {
 	Table.set("arm1: partial length"+i, 0, 0);
 }
  for(i=1;i<=maxArm2PartialLengthCounter;i++)
 {
 	Table.set("arm2: partial length"+i, 0, 0);
 }
 for(i=0;i<lengthOf(totalNewPartialLengthArray);i++)
 {
 	Table.set(totalArmNewPartialLengthArray[i], totalRowArmNewPartialLengthArray[i],totalNewPartialLengthArray[i]);
 }
 Table.update;
}//end of function modifyResultsTable
/*
 * This function is going to use the SCsArray to check whether there is more than one centromere per SC. In case there is, it is going to draw them and 
 * create a GUI so the user can decide which one to keep.
 */
function checkCentromeresPerSC()
{
	//SCsArray=newArray(0,1,2,3,1,1,2);//Uncoment this line to check the function
	//print("SCsArray: ");
	//Array.print(SCsArray);
	for(i=0;i<lengthOf(SCsArray);i++)
	{
		//print("------i: "+i);
		actualValue=SCsArray[i];
		//print("actualValue: "+actualValue);
		actualValueIndex=i;
		//print("actualValueIndex: "+actualValueIndex);
		if(actualValue!=0)
		{
			indexesString=toString(actualValueIndex);
			nCentromeresPerSC=1;//1 me
			for(j=i+1;j<lengthOf(SCsArray);j++)//count the number of repetitions
			{
				//print("j: "+j);
				nextValue=SCsArray[j];
				//print("nextValue: "+nextValue);
				nextValueIndex=j;
				//print("nextValueIndex: "+nextValueIndex);
				if (actualValue==nextValue)
				{
					nCentromeresPerSC++;
					//print("nCentromeresPerSC: "+nCentromeresPerSC);
					indexesString=indexesString+","+nextValueIndex;
					//print("indexesString: "+indexesString);	
					indexesArray=split(indexesString,",");
					//print("indexesArray: ");
					//Array.print(indexesArray);					
				}
			}
			if(nCentromeresPerSC>1)
			{
				selectedCentromereIndex=showGUI();
				for(k=0;k<nCentromeresPerSC;k++)
				{
					if(indexesArray[k] != selectedCentromereIndex)
					{
						//print("SCsArray:");
						//Array.print(SCsArray);
						SCsArray[indexesArray[k]]=0;
					}
					
				}
				//print("SCsArray: ");
				//Array.print(SCsArray);
			}
		}
	}
}
/*
 * This function is used by the function checkCentromeresPerSC to draw all centromeres on an SC and ask the user to select the one to keep.
 */

function showGUI()
{
	roiManager("reset");
	xPoint=newArray(nCentromeresPerSC);
	yPoint=newArray(nCentromeresPerSC);
	for(i=0;i<lengthOf(indexesArray);i++)
	{
		xPoint[i]=modXPoints[indexesArray[i]];
		yPoint[i]=modYPoints[indexesArray[i]];
	}
	for(i=0;i<lengthOf(xPoint);i++)
	{
		makePoint(xPoint[i],yPoint[i],"circle large white");
		roiManager("add");
		roiManager("select",i);
		roiManager("rename",i+1);
		roiManager("deselect");
		roiManager("show all with labels");
	}
	Dialog.createNonBlocking("Synaptonemal & CO analyzer");
	label="More than one centromere have been detected for the centromere in the image while only one is allowed\nChoose the centromere to keep.";
	//roiManager("reset");
	items=newArray(nCentromeresPerSC);
	for(i=0;i<nCentromeresPerSC;i++)
	{
		items[i]=toString(i+1);

	}
	Dialog.addChoice(label, items);
	Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
	Dialog.show();
	if(selectionType()!=-1)
	{
		run("Select None");
	}
	selectedCentromere=Dialog.getChoice();
	//print("SelectedCentromere: "+selectedCentromere);
	selectedCentromereIndex=indexesArray[selectedCentromere-1];
	return selectedCentromereIndex;
}
		