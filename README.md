# h5io

## Overview

This repository contains tools to read and write HDF5 files. HDF5 files are a performant tool for storing scientific data, and are supported in many programming languages. For more information on the specifics of HDF5 files, visit the [HDF Group website](https://www.hdfgroup.org/solutions/hdf5/). To gain insight into the contents of specific HDF5 files, the HDF Group provides a useful tool called [HDFView](https://www.hdfgroup.org/downloads/hdfview/).

This MATLAB package includes tools for reading and writing at the file, group, attribute, and dataset levels. These tools allow the user to write powerful serialization/deserialization methods in MATLAB. It aims to be a bit easier to use than Mathworks' implementations.

To install this package, clone the repository on your machine and add the src/ folder to your MATLAB path.

## Write Examples

Create a new file, called my_h5.hdf5

```Matlab
filename = fullfile(cd,'my_h5.hdf5');
my_h5_obj = h5io.file(filename,'w');
```

Create a group within my_h5.hdf5, call it my_group

```Matlab
my_group_obj = my_h5_obj.add_group('my_group');
```

Create an attribute within my_group, call it my_attribute and give it a value of 7

```Matlab
my_group_obj.attributes.my_attribute = 7;
```

Create a dataset within my_group, call it eye_3 and give it a value of a 3x3 identity matrix

```Matlab
my_group_obj.add_dataset('eye_3',eye(3));
```
