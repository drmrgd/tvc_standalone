TVC Standalone Environment
--

A launcher script and some utilities for running TVCv4.2+ standalone.  This repo will allow one to perform
some custom variant calling analysis and troubleshooting using the Torrent Variant Caller as a standalone
utility.  It is only possible to use this with versions >4.2, as earlier versions require a complete TS 
environment to run.  

This repo requires the following in order to run correctly:

* A compiled version of TVC.  This may work with the default TVC plugin, but this is as of yet untested. This
  is not a component of this repo and must be obtained directly from the vendor.

* The config file (for now) must be placed in the working directory (usually your TVC build dir), and the values
  (especially the <i>TVC_ROOT_DIR</i> parameter) must be set accordingly

* BED files processed through `tvcutils`

* TS processed reference sequence with .dict file

* Directory of BAM files

In general setting up a working directory similar to this will aid in running custom analyses:

`
    .
    ├── bams
    │   └── <dir_of_bams> #must be indexed
    ├── bed
    │   └── <bed/vcf_files>
    ├── config
    ├── output
    ├── params
    │   └── <tvc_param_files>
    ├── <reference_dir>
    ├── tvc_launcher.sh
    └── variantCaller_v4.2.2
        └── <build_files>
`
A skeleton working directory environment is provided, and can be populated with the files necessary to process a run.
This is only out of convenience, however, as the file paths can be where you want, as long as this is reflected in
the 'config' file.

<b><i>Note:</i></b> The TVC binaries are not provided in this repo and must be obtained from the vendor directly
