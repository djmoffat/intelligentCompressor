# intelligentCompressor
This is the repo for an intelligent compressor, written in Matlab. This VST plugin uses the Matlab Audio Systems Toolbox

The code can be tested and prototyped in the Matlab environment, using the code

``` Matlab
audioTestBench autocomp
```

The following code will compile the Matlab code direct to VST 

``` Matlab
validateAudioPlugin autocomp
generateAudioPlugin autocomp
```

## Referencing 
When using this code, please reference the following paper
        
```David Moffat and Mark B. Sandler, “Adaptive Ballistics Control of Dynamic Range Compression for Percussive Tracks”, In Proc. 145th Audio Engineering Society Convention, New York, USA, October 2018```

``` latex

@inproceedings{moffat18compressor,
        Title = {Adaptive Ballistics Control of Dynamic Range Compression for Percussive Tracks},
	Author = {Moffat, David and Sandler, Mark B},
	Booktitle = {Audio Engineering Society Convention 145 (to appear)},
	Month = {October},
	Address = {New York, USA},
        Year = {2018}}
```

## Contact
Any question, please contact me
