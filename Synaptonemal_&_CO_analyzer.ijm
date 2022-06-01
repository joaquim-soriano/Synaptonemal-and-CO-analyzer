/*		
 * 		This function is meant to delete all slices in a stack but one containing COs, SCs or nuclei.
 * 		The slice to keep is introduced in the parameter slice, in the macro it is stored in the variables: COsSlice, SCsSlice o nucleiSlice.
 * 		E.g.: COsSlice=1 means that the first slice in the image stack contains COs.
 */

SCsSlice=2;
COsSlice=1;
nucleiSlice=3;
//selectSlice(SCsSlice);
//selectSlice(COsSlice);
selectSlice(nucleiSlice);
		
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
}

