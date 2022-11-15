 /*   <SC detection macro recorder>
    Copyright (C) 2022  Joaquim Soriano Felipe

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
/*This macro is intended as a tool to be used for users of the macro Synaptonemal_&_CO_analyzer.
 * It is meant to ease skeletonize Synaptonemal Complexes in fluorescent images of cells spreads.
 * Designed for users with no image analysis training.
 * Good enough image quality is supposed since the macro is not aimed as a general image processing tool.
 * Input: images of fluorescent cells spreads, at least one channel should contain SC labels.
 * Output: text file containing code that can be copied and pasted into the macro Synaptonemal_&_CO_analyzer.
 * The macro guides the user through a series of steps whose aim is to get an image of the skeletons of the SCs as accurate as possible.
 * The user is given the choice to repeat the process as many times as needed. Once results good enough results are achieved, the resulting algorithm 
 * is saved as macro code in a text file.
 * Version 2 adds the possibility of filtering SCs by size and corrects a bug that caused Gaussian blur filter to implement allways a 1 sigma radius.
 * Version 3 only prints to the text file if the user is happy with results
 */
Dialog.createNonBlocking("SC detection macro recorder");
Dialog.addMessage("The following wizard will guide you through a few consecutive steps that will help you detect the SCs in your images.\nIt might take some attempts before you get appropriate results.\nDetection does not need to be perfect since fused, discontinued and overlapped SCs can be corrected in the Synaptonemal & CO analyzer macro.\nOnce done, you'll get a piece of code in a text file that you can paste to the Synaptonemal & CO analyzer macro.");
Dialog.addMessage("Once pressing \"OK\", all open images, the Log, the ROI Manager and the Results window will be closed or reseted.");
Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
Dialog.show();
fs=File.separator;
/*
Dialog.create("Synaptonemal & CO analyzer");
Dialog.addMessage("Once pressing \"OK\", all open images, the Log, the ROI Manager and the Results window will be closed or reseted.");
Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
Dialog.show();
*/
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


/////////////////////MACRO BEGINS
//var resultsString="";
representativeImageName=File.openDialog("Choose the image to analyze.");
fileExtension=substring(representativeImageName, lastIndexOf(representativeImageName,"."));
//print("fileExtension: "+fileExtension);
dir=File.directory;
//print("dir: "+dir);
dirFileListArray=getFileList(dir);//Get image's path
//resultsDir=dir+fs+"Results-macro recording";
if(File.exists(dir+"SC_detection_code.txt"))
{
	File.delete(dir+"SC_detection_code.txt");
}
//textFile=File.open(dir+"SC_detection_code.txt");
happyWithResults=false;
do{
	if(File.exists(dir+"SC_detection_code.txt"))
	{
	File.delete(dir+"SC_detection_code.txt");
	}
	//textFile=File.open(dir+"SC_detection_code.txt");
	roiManager("reset");
	run("Bio-Formats", "open=["+representativeImageName+"] color_mode=Colorized rois_import=[ROI manager] split_channels view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder	
	run("Cascade");
	waitForUser("Title", "The different channels of the images you chose are open.\n Close the ones you are not interested in.\n Keep open the channel showing the SCs.");	
	openImagesArray=getList("image.titles");
	if(lengthOf(openImagesArray)>1)
	{
		exit("More than an image is open while only one is expected.\nThe macro will exit.\nPlease run it again following the steps precisely.");
	}
	selectWindow(""+openImagesArray[0]+"");
	imageID=getImageID();
	Dialog.create("SC detection macro recorder");
	Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
	Dialog.addMessage("Gaussian blur filter might remove unwanted bifurcations in your final SCs skeletons, but could also merge really close ones.\nSkip this option at first and choose it if your SC skeletons show unwanted protuberances.\nIncrease sigma gradually form 1 to 3 until no protuberances are seen.\nOnly integers are accepted.");
	Dialog.addCheckbox("Gaussian Blur Filter", false);
	Dialog.addToSameRow();
	Dialog.addNumber("sigma", 1);
	Dialog.show();
	blur=Dialog.getCheckbox();
	sigma=Dialog.getNumber();
	if(indexOf(toString(sigma), ".")!=-1)
	{
		exit("The number introduced in the Gaussian Blur operation is not an integer.\nThe macro will exit.\nPlease try again.");
	}
	if(blur)
	{
		selectImage(imageID);
		run("Gaussian Blur...", "sigma="+sigma);
		//print(textFile, "run(\"Gaussian Blur...\", \"sigma="+sigma+"\");");
		//resultsString=resultsString+"run(\"Gaussian Blur...\", \"sigma="+sigma+"\");");
		}
			
	run("Threshold...");	
	waitForUser("Threshold step: move the sliders so the SCs are highlighted in red as best as possible.\nYou can get rid off small non-SCs highlighted objects afterwards.\nFused, discontinued and overlapped SCs can be corrected in the Synaptonemal & CO analyzer macro.\nDo not apply the threshold.");
	getThreshold(lower, upper);
	//print(textFile, "run(\"Threshold...\");");
	//resultsString=resultsString+"setThreshold("+lower+", "+upper+");";
	//print(textFile, "setThreshold("+lower+", "+upper+");");
	//resultsString=resultsString+"setOption(\"BlackBackground\", true);";
	//print(textFile, "setOption(\"BlackBackground\", true);");
	//resultsString=resultsString+"setOption(\"BlackBackground\", true);";
	//print(textFile, "run(\"Convert to Mask\");");
	//resultsString=resultsString+"run(\"Convert to Mask\");";
	setOption("BlackBackground", true);
	run("Convert to Mask");
	if(isOpen("Threshold"))
	{
		selectWindow("Threshold");
		run("Close");
	}
	Dialog.createNonBlocking("SC detection macro recorder");
	Dialog.addMessage("The following options usually sufice to process SCs for Synaptonemal_&_CO_analyzer plugin.\nSome recommendations for selection are done.\nVisit: https://imagej.nih.gov/ij/docs/guide/index.html for more info.");
	Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
	//Dialog.addMessage("Gaussian blur filter might remove unwanted bifurcations in your final SCs skeletons, but could also merge really close ones.\nSkip this option at first and choose it if your SC skeletons show unwanted protuberances.");
	//Dialog.addCheckbox("Gaussian Blur Filter", false);
	Dialog.addMessage("The reconstruct binary operation deletes objects based on size and shape while keeping the rest unaltered.\nUse it to get rid of small objects\nSet by trial/error until you see small objects disapear (but no SC disappearing)\nA temptative starting value: [SCs width (pixels)/2]-1\nIntroduce an integer, the bigger the bigger objects will disappear.");
	Dialog.addCheckbox("Reconstruc binary operation", false);
	Dialog.addToSameRow();
	Dialog.addNumber("erosions", 1);//comprobar que el número añadido es un integer
	Dialog.addMessage("The open binary operation smooths SCs outlines.\nIt might remove unwanted bifurcations in your final SCs skeletons\nSkip this option at first and choose it if your SC skeletons show unwanted protuberances.");
	Dialog.addCheckbox("Open binary operation", false);
	Dialog.addMessage("Filtering SCs by size allows for getting rid of too small objects. \nEnter the minimum size (in the units your image is in) of the SCs you would like to keep.\nYou can measure the size of the SCs using the segmented line tool.");
	Dialog.addCheckbox("Filter SCs by size: ", false);
	Dialog.addNumber("Minimum SCs size: ", 0, 0, 7, "units in the image");
	Dialog.show();
	

	reconstruct=Dialog.getCheckbox();
	reconstructErosions=Dialog.getNumber();
	openBinaryOperation=Dialog.getCheckbox();
	sizeFiltering=Dialog.getCheckbox();
	minimumSCsSize=Dialog.getNumber();

	if(reconstruct)
	{
		if(indexOf(toString(reconstructErosions), ".")!=-1)
		{
			exit("The number introduced in the binary operation field is not an integer.\nThe macro will exit.\nPlease try again.");
		}
		selectImage(imageID);
		run("BinaryFilterReconstruct ", "erosions="+reconstructErosions+" white");
		//print(textFile, "run(\"BinaryFilterReconstruct \", \"erosions="+reconstructErosions+" white\");");
		//resultsString=resultsString+"run(\"BinaryFilterReconstruct \", \"erosions="+reconstructErosions+" white\")";
		
	}
	if(openBinaryOperation)
	{
		selectImage(imageID);
		run("Open");
		//print(textFile, "run(\"Open\");");
		//resultsString=resultsString+"run(\"Open\");";
	}
	setOption("BlackBackground", true);
	roiManager("reset");
	selectImage(imageID);
	run("Skeletonize");
	//print(textFile, "run(\"Skeletonize\");");
	selectImage(imageID);
	if(sizeFiltering)
	{
		Overlay.remove;
		run("Analyze Particles...", "size="+minimumSCsSize+"-Infinity show=Overlay");
		if(Overlay.size!=0)
		{
			run("Select All");
			setBackgroundColor(0, 0, 0);
			run("Clear", "slice");
			Overlay.fill("white");
			run("Remove Overlay");
			Overlay.clear;
			Overlay.hide;
			run("Select None");
		}
		
		//print(textFile, "run(\"Analyze Particles...\", \"size="+minimumSCsSize+"-Infinity add\");");
	}

	run("Create Selection");//solo si no se ha seleccionado el filtro de partículas
	if(selectionType!=-1)
	{
			roiManager("add");
	}

	close();
	run("Bio-Formats", "open=["+representativeImageName+"] color_mode=Colorized rois_import=[ROI manager] split_channels view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder	
	selectWindow(""+openImagesArray[0]+"");
	close("\\Others");
	roiManager("show all without labels");
	Dialog.createNonBlocking("Synaptonemal & CO analyzer");
	Dialog.addCheckbox("Check if you are you happy with results, keep unchecked to try again", false);
	Dialog.show();
	happyWithResults=Dialog.getCheckbox();
	close("*");

	//File.close(textFile);
}
while(!happyWithResults)
//save a text file will all performed operations
textFile=File.open(dir+"SC_detection_code.txt");
if(blur){print(textFile, "run(\"Gaussian Blur...\", \"sigma="+sigma+"\");");}
print(textFile, "run(\"Threshold...\");");
print(textFile, "setThreshold("+lower+", "+upper+");");
print(textFile, "setOption(\"BlackBackground\", true);");
print(textFile, "run(\"Convert to Mask\");");
if(reconstruct){
	print(textFile, "run(\"BinaryFilterReconstruct \", \"erosions="+reconstructErosions+" white\");");
	}
if(openBinaryOperation){print(textFile, "run(\"Open\");");}
print(textFile, "run(\"Skeletonize\");");
if(sizeFiltering){
//////////////	
//Overlay.remove;
print(textFile,"Overlay.remove;");
print(textFile, "run(\"Analyze Particles...\", \"size="+minimumSCsSize+"-Infinity show=Overlay\");");
//run("Analyze Particles...", "size="+minimumSCsSize+"-Infinity show=Overlay");
print(textFile,"if(Overlay.size!=0)");
print(textFile,"{");
print(textFile,	"run(\"Select All\");");
print(textFile,	"setBackgroundColor(0, 0, 0);");
print(textFile,	"run(\"Clear\", \"slice\");");
print(textFile,	"Overlay.fill(\"white\");");
print(textFile,	"run(\"Remove Overlay\");");
print(textFile,	"Overlay.clear;");
print(textFile,	"Overlay.hide;");
print(textFile,	"run(\"Select None\");");
print(textFile,"}");
}
	
////////////////	
	
	//print(textFile, "run(\"Analyze Particles...\", \"size="+minimumSCsSize+"-Infinity add\");");
	//}
File.close(textFile);
exit("The macro is done the file SC_detection_code.txt has been created in "+dir+"\nCopy and paste its contents into the Synaptonemal_&_CO_analyzer macro to fine tune your SC's detection");