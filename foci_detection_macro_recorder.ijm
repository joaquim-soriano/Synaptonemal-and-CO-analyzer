 /*   <foci detection macro recorder.>
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
 * It is meant to ease detecting bead-like particles (usually crossovers or centromeres) in fluorescent images of cells spreads.
 * Designed for users with no image analysis training.
 * Good enough image quality is supposed since the macro is not aimed as a general image processing tool.
 * Input: images of fluorescent cells spreads, at least one channel should contain foci labels (usually crossovers or centromeres).
 * Output: text file containing code that can be copied and pasted into the macro Synaptonemal_&_CO_analyzer.
 * The macro guides the user through a series of steps whose aim is to get a results table containing centromeres'/COs' centers of mass as 
 * accurate as possible. 
 * Such table should equal the ones that imageJ creates when analyzing particles: it should contain detected foci in rows, and X and Y centers 
 * of mass coordinates in two columns entitled XM and YM. The easiest way to create this table is by performing a center of mass analysis in 
 * imageJ.
 * The user is given the choice to repeat the process as many times as needed. Once good enough results are achieved, the resulting algorithm is 
 * saved as macro code in a text file.
 * Version 2 adds the possibility of filtering SCs by size and corrects a bug that caused Gaussian blur filter to implement allways a 1 sigma radius.
 * Version 3 only prints to the text file if the user is happy with results
 */
Dialog.create("Foci detection macro recorder");
Dialog.addMessage("The following wizard will guide you through a few consecutive steps that will help you detect the foci (usually crossovers or centromeres) in your images.\nIt might take some attempts before you get appropriate results.\nDetection does not need to be perfect since foci can be added/erased in the Synaptonemal & CO analyzer macro.\nOnce done, you'll get a piece of code in a text file that you can paste to the Synaptonemal & CO analyzer macro.");
Dialog.addMessage("Once pressing \"OK\", all open images, the Log, the ROI Manager and the Results window will be closed or reseted.");
items1=newArray("crossovers", "centromeres");
Dialog.addChoice("Are you willing to detect crossovers or centromeres?", items1);
items2=newArray("Shape, size and intensity", "Local intensity maxima");
Dialog.addChoice("Based on which criteria?", items2);
Dialog.setLocation(0.01*screenWidth, 0.01*screenHeight);
Dialog.show();
fociType=Dialog.getChoice();//fociType=crossovers or centromeres
detectionAnalysis=Dialog.getChoice();
fs=File.separator;
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
representativeImageName=File.openDialog("Choose the image to analyze.");
fileExtension=substring(representativeImageName, lastIndexOf(representativeImageName,"."));
//print("fileExtension: "+fileExtension);
dir=File.directory;
//print("dir: "+dir);
dirFileListArray=getFileList(dir);//Get image's path
//resultsDir=dir+fs+"Results-macro recording";
if(File.exists(dir+fociType+"_detection_code.txt"))
{
	waitForUser("A "+fociType+"_detection_code.txt does already exist in "+dir+"\nIt will be erased unless you change its name or move it to a different location.");
	if(File.exists(dir+fociType+"_detection_code.txt"))
	{
		File.delete(dir+fociType+"_detection_code.txt");
	}
}

/////////////////////////////////////////////////////////////////////////
/////////////////SHAPE, SIZE AND INTENSITY ANALYSIS/////////////////////
////////////////////////////////////////////////////////////////////////

if(detectionAnalysis=="Shape, size and intensity")
{
	happyWithResults=false;
	do{
		if(File.exists(dir+fociType+"_detection_code.txt"))
		{
		File.delete(dir+fociType+"_detection_code.txt");
		}
		run("Bio-Formats", "open=["+representativeImageName+"] color_mode=Colorized rois_import=[ROI manager] split_channels view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder	
		run("Cascade");
		waitForUser("Foci detection macro recorder", "The different channels of the images you chose are open.\n Close the ones you are not interested in.\n Keep open the channel showing the "+fociType+".");	
		openImagesArray=getList("image.titles");
		if(lengthOf(openImagesArray)>1)
		{
			exit("More than an image is open while only one is expected.\nThe macro will exit.\nPlease run it again following the steps precisely.");
		}
		selectWindow(""+openImagesArray[0]+"");
		imageID=getImageID();
		setAutoThreshold("Default dark");
		run("Threshold...");
		waitForUser("Use the threshold tool to highlight in red the foci you are interested in.\nDo not apply the threshold.\nTake note of the approximate size in pixels of the foci.\nPress OK when done.");
		getThreshold(lower, upper);
		do{
			correctMenuChoices=true;
			Dialog.create("Foci detection macro recorder");
			Dialog.addNumber("Enter the minimum size (in pixels) of the foci you are interested in.", 0, 0, 9, "pixels");
			Dialog.addNumber("Enter the maximum size (in pixels) of the foci you are interested in.", 100, 0, 9, "pixels");
			Dialog.addMessage("Foci out of the minimum-maximum range will be ignored.\nSet the maximum size value to zero to select all foci independently of its maximum size.\n \n " );
			Dialog.addNumber("Enter the minimum circularity value of the foci you are interested in.", 0, 1, 2, "pixels");
			Dialog.addNumber("Enter the maximum circularity value of the foci you are interested in.", 1, 1, 2, "pixels");
			Dialog.addMessage("The maximum circularity value is 1.0, which indicates a perfect circle, the lower the value the farthest from the perfect circle.");
			Dialog.show();
			minimumSize=Dialog.getNumber();
			maximumSize=Dialog.getNumber();
			minimumCircularity=Dialog.getNumber();
			maximumCircularity=Dialog.getNumber();
			//print("minimumSize: "+minimumSize);
			//print("maximumSize: "+maximumSize);
			//print("minimumCircularity: "+minimumCircularity);
			//print("maximumCircularity: "+maximumCircularity);
			minimumSizeString=toString(minimumSize);
			maximumSizeString=toString(maximumSize);
			minimumCircularityString=toString(minimumCircularity);
			maximumCircularityString=toString(maximumCircularity);
			uncorrectMenuChoicesString="";
			if(maximumSize==0)
			{
				maximumSize=9999999999999;
			}
			if(minimumSizeString=="NaN")
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe minimum size value is text and should be an integer value.\nRemember not to use commas instead of dots.";
				correctMenuChoices=false;
			}
			if(minimumSizeString.contains("."))
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe minimum size value: "+minimumSize+", should be an integer value.";
				correctMenuChoices=false;
			}
						
			if(maximumSizeString=="NaN")
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe maximum size value is text and should be an integer value.\nRemember not to use commas instead of dots.";
				correctMenuChoices=false;
			}
			if(maximumSizeString.contains("."))
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe maximum size value: "+maximumSize+", should be an integer value.";
				correctMenuChoices=false;
			}
			if(minimumSize>maximumSize)
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe minimum size value is bigger than the maximum sixe value.";
				correctMenuChoices=false;
			}
			if(minimumCircularityString=="NaN")
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe minimum circularity value is text and should be an integer value.\nRemember not to use commas instead of dots.";
				correctMenuChoices=false;
			}
			if(maximumCircularityString=="NaN")
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe maximum circularity value is text and should be an integer value.\nRemember not to use commas instead of dots.";
				correctMenuChoices=false;
			}
			if(minimumCircularity>maximumCircularity)
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe minimum circularity value is bigger than the maximum circularity value.";
				correctMenuChoices=false;
			}
			if(minimumCircularity>1 || maximumCircularity>1)
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe circularity values should never be bigger than 1.";
				correctMenuChoices=false;
			}
			if(!correctMenuChoices)
			{
				//It is not possible to create a recursive loop here (to avoid exiting the macro), an annoying error occurs
				exit(uncorrectMenuChoicesString+"\nThe macro will exit, try again introducing correct menu values.");
			}
		}
		while(!correctMenuChoices)
	run("Set Measurements...", "center limit redirect=None decimal=0");
	if(maximumSize==9999999999999)
	{
		maximumSizeString="Infinity";		
	}
	run("Analyze Particles...", "size="+minimumSizeString+"-"+maximumSizeString+" circularity="+minimumCircularityString+"-"+maximumCircularityString+" show=Overlay display clear include");			 
	Dialog.createNonBlocking("foci detection macro recorder");
	Dialog.addCheckbox("Check if you happy with detected foci. Detection does not need to be perfect since foci can be added/erased in the Synaptonemal & CO analyzer macro.", false);
	Dialog.show();
	happyWithResults=Dialog.getCheckbox();
	//happyWithResults=getBoolean("Are you happy with detected foci?. Detection does not need to be perfect since foci can be added/erased in the Synaptonemal & CO analyzer macro.", "Yes, I'm done.", "No, let me try again");
	selectImage(imageID);
	close();
	}
	while(!happyWithResults)
	textFile=File.open(dir+fociType+"_detection_code.txt");
	print(textFile, "run(\"Set Measurements...\", \"center limit redirect=None decimal=0\");");
	print(textFile, "setThreshold("+lower+","+upper+");");
	print(textFile, "run(\"Analyze Particles...\", \"size="+minimumSizeString+"-"+maximumSizeString+" circularity="+minimumCircularityString+"-"+maximumCircularityString+" show=Nothing display clear include\");");		 
	print(textFile, "resetThreshold();");
	print(textFile, "if(isOpen(\"Threshold\"))");
	print(textFile, "{");
	print(textFile, "selectWindow(\"Threshold\");");
	print(textFile, "run(\"Close\");");
	print(textFile, "}");
	File.close(textFile);
	if(isOpen("Threshold"))
	{
		selectWindow("Threshold");
		run("Close");
	}
}	
	
/////////////////////////////////////////////////////////////////////
/////////////////LOCAL INTENSITY MAXIMA ANALYSIS/////////////////////
////////////////////////////////////////////////////////////////////

if(detectionAnalysis=="Local intensity maxima")
{
	happyWithResults=false;
	do{
		if(File.exists(dir+fociType+"_detection_code.txt"))
		{
		File.delete(dir+fociType+"_detection_code.txt");
		}
		run("Bio-Formats", "open=["+representativeImageName+"] color_mode=Colorized rois_import=[ROI manager] split_channels view=Hyperstack stack_order=XYCZT");//Open fileExtension files in image's folder	
		run("Cascade");
		waitForUser("Foci detection macro recorder", "The different channels of the images you chose are open.\n Close the ones you are not interested in.\n Keep open the channel showing the "+fociType+".");	
		openImagesArray=getList("image.titles");
		if(lengthOf(openImagesArray)>1)
		{
			exit("More than an image is open while only one is expected.\nThe macro will exit.\nPlease run it again following the steps precisely.");
		}
		selectWindow(""+openImagesArray[0]+"");
		imageID=getImageID();
		do{
			correctMenuChoices=true;
			Dialog.create("Foci detection macro recorder");
			Dialog.addNumber("Enter a prominenece value: ", 10, 2, 4, "");
			Dialog.addMessage("Only foci that stand out from the surroundings by more than this value will be selected");
			Dialog.show;
			prominence=Dialog.getNumber();
			//print("prominence: "+prominence);
			prominenceString=toString(prominence);
			//print("prominenceString: "+prominenceString);
			uncorrectMenuChoicesString="";
			if(prominenceString=="NaN")
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe prominence value is text and should be a positive number.\nRemember not to use commas instead of dots.";
				correctMenuChoices=false;
			}
			if(prominenceString.contains("-"))
			{
				uncorrectMenuChoicesString=uncorrectMenuChoicesString+"\nThe prominenece value should be a positive number.";
				correctMenuChoices=false;
			}
			if(!correctMenuChoices)
			{
				//It is not possible to create a recursive loop here (to avoid exiting the macro), an annoying error occurs
				exit(uncorrectMenuChoicesString+"\nThe macro will exit, try again introducing correct menu values.");
			}
		}
		while(!correctMenuChoices)
		run("Find Maxima...", "prominence="+prominence+" strict output=[Point Selection]");
		Dialog.createNonBlocking("foci detection macro recorder");
		Dialog.addCheckbox("Check if you happy with detected foci. Detection does not need to be perfect since foci can be added/erased in the Synaptonemal & CO analyzer macro.", false);
		Dialog.show();
		happyWithResults=Dialog.getCheckbox();
		//happyWithResults=getBoolean("Are you happy with detected foci?. Detection does not need to be perfect since foci can be added/erased in the Synaptonemal & CO analyzer macro.", "Yes, I'm done.", "No, let me try again");
		//getBoolean(message, yesLabel, noLabel);
		selectImage(imageID);
		close();
	}
	while(!happyWithResults)
	textFile=File.open(dir+fociType+"_detection_code.txt");
	print(textFile, "run(\"Find Maxima...\", \"prominence="+prominence+" strict output=[Point Selection]\");");
	print(textFile, "run(\"Set Measurements...\", \"center display redirect=None decimal=3\");");
	print(textFile, "run(\"Measure\");");
	File.close(textFile);
}	

exit("The macro is done the file "+fociType+"_detection_code.txt has been created in "+dir+"\nCopy and paste its contents into the Synaptonemal_&_CO_analyzer macro to fine tune your "+fociType+" detection");