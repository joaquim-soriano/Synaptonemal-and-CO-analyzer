var initialX, initialY;
startingPoint();
print("initialX: "+initialX);
print("initialY. "+initialY);


function startingPoint(){
/*
 * Esta función localiza la coordenada de inicio de una ROI lineal (se diseñó para cromosomas). La coordenada de inicio se considera la más a la izquierda. Si una coordenada de inicio y final 
 * comparten la misma x, entonces se elige la y menor (el extremo superior). No funcionará con ROIs que se bifurcan.
 */

	Roi.getContainedPoints(xpoints, ypoints);
	//getSelectionCoordinates(xpoints, ypoints);
	print("xpoints: ");
	Array.print(xpoints);
	print("ypoints: ");
	Array.print(ypoints);
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
	print("neighboursArray: ");
	Array.print(neighboursArray);
	xFinalPointsArray=newArray(2);
	yFinalPointsArray=newArray(2);
	finalPointsCounter=0;
	for(i=0;i<lengthOf(neighboursArray);i++)
	{
		if(neighboursArray[i]==1)
		{
			xFinalPointsArray[finalPointsCounter]=xpoints[i];
			yFinalPointsArray[finalPointsCounter]=ypoints[i];
	
			print("La ROI empieza o acaba en : "+xpoints[i]+", "+ypoints[i]);
			print("La ROI empieza o acaba en: "+xFinalPointsArray[finalPointsCounter]+", "+yFinalPointsArray[finalPointsCounter]);
			finalPointsCounter++;
		}
	}
	x1=xFinalPointsArray[0];
	x2=xFinalPointsArray[1];
	y1=yFinalPointsArray[0];
	y2=yFinalPointsArray[1];
	xDifference=x1-x2;
	if(xDifference<0)
	{
		print("xDifference<0");
		initialX=x1;
		initialY=y1;
	}
	else if(xDifference>0)
	{
		print("xDifference>0");
		initialX=x2;
		initialY=y2;
	}
	else if(xDifference==0)
	{
		print("xDifference==0");
		yDifference=y1-y2;
		if(yDifference<0)
		{
			initialX=x1;
			initialY=y1;
		}
		else if(yDifference>0)
		{
			initialX=x2;
			initialY=y2;
		}
	}
	print("initialX: "+initialX);
	print("initialY. "+initialY);
}