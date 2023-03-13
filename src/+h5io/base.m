classdef base < handle
%BASE Base class for HDF5 objects
    properties (Access = protected, Transient)
        %OBJID ID for the H5 object
        objID;
    end
    properties (Dependent)
        %NAME Name of the object
        name
        %LINK Link within the HDF5 file
        link;
        %INFO 
        info;
        %COMMENT Comment tied to this object
        comment;
        %ATTRIBUTES Attributes tied to this object
        attributes;
    end
    methods
        % Getters and Setters
        function name = get.name(this)
            link_txt = this.link;
            name = 'root';
            if numel(link_txt) > 1
                name = link_txt(find(link_txt == '/',1,'last')+1:end);
            end
        end
        function link = get.link(this)
            link = H5I.get_name(this.objID);
        end
        function info = get.info(this)
            info = H5O.get_info(this.objID);
        end
        function comment = get.comment(this)
            comment = H5O.get_comment(this.objID);
        end
        function set.comment(this,comment)
            if ~ischar(comment)
                error('Comment must be a character array');
            end
            H5O.set_comment(this.objID,comment);
        end
        function attributes = get.attributes(this)
            attributes = struct;
            for i = 1:this.info.num_attrs
                attr_id = H5A.open_idx(this.objID,i-1);
                attr_name = H5A.get_name(attr_id);
                attr_val = this.h5postprocessattr(attr_id);
                attributes.(attr_name) = attr_val;
                H5A.close(attr_id)
            end
        end
        function set.attributes(this,attributes)
            
            % Only try if the input is a struct
            if ~isstruct(attributes)
                error('Cannot change field ''attributes''');
            end
            
            % Get input info and state of class
            new_fields = fieldnames(attributes);
            attributes_old = this.attributes;
            old_fields = fieldnames(attributes_old);
            
            % Loop through the input structure
            for i = 1:numel(new_fields)
                
                % Current field being accessed
                new_field = new_fields{i};
                
                % Check if the field actually needs to get written, delete
                % the old value if so
                write_field = false;
                attr_exists = false;
                if any(strcmpi(new_field,old_fields))
                    if ~isequal(attributes.(new_field),attributes_old.(new_field))
                        attr_exists = true;
                        write_field = true;
                    end
                else
                    write_field = true;
                end
                
                % Write the field if we've gotten this far
                if write_field
                    type_id  = this.mlType_to_h5Type(attributes.(new_field));
                    space_id = this.attr_dataspaceID(attributes.(new_field));
                    acpl_id  = H5P.create('H5P_ATTRIBUTE_CREATE');
                    if attr_exists
                        this.rmattribute(new_field);
                    end
                    attr_id  = H5A.create(this.objID,new_field,type_id,space_id,acpl_id);
                    H5A.write(attr_id,type_id,attributes.(new_field)');
                    H5T.close(type_id);
                    H5P.close(acpl_id);
                    H5S.close(space_id);
                    H5A.close(attr_id);
                end
                
            end
            
        end
        % Destructor
        function delete(this)
        %DELETE Class destructor
            
            % Delete reference to the obj if it's still valid
            if ~isempty(this.objID)
                if H5I.is_valid(this.objID)
                    H5O.close(this.objID);
                end
            end
            this.objID = [];
            
        end
        % Other
        function rmattribute(this,attr_name)
        %RMATTRIBUTE Remove an attribute by name
        
            H5A.delete(this.objID,attr_name);
            
        end
    end
    methods (Access = protected, Static)
        function dsID = attr_dataspaceID(mlObj)
        %ATTR_DATASPACEID Setup the dataspace ID.  This just depends on 
        %how many elements the attribute actually has.

            if isempty(mlObj)
                dsID = H5S.create('H5S_NULL');
                return;
            elseif ischar(mlObj)
                if isrow(mlObj)
                    dsID = H5S.create('H5S_SCALAR');
                    return
                else
                    error(message('MATLAB:imagesci:h5writeatt:badStringSize'));
                end
            else
                if ismatrix(mlObj) && ( any(size(mlObj) ==1) )
                    rank = 1;
                    dims = numel(mlObj);
                else
                    % attribute is a "real" 2D value.		
                    rank = ndims(mlObj);
                    dims = fliplr(size(mlObj));
                end
            end
            dsID = H5S.create_simple(rank,dims,dims);
            
        end
        function attr_val = h5postprocessattr(attr_id)
        % Read the datatype information and use that to possibly post-process
        % the attribute data.
        
            raw_attr_val = H5A.read(attr_id);
            attr_type = H5A.get_type(attr_id);
            attr_class = H5T.get_class(attr_type);
        
            persistent H5T_ENUM H5T_OPAQUE H5T_STRING H5T_INTEGER H5T_FLOAT H5T_BITFIELD H5T_REFERENCE;
            if isempty(H5T_ENUM)
                H5T_ENUM = H5ML.get_constant_value('H5T_ENUM');
                H5T_OPAQUE = H5ML.get_constant_value('H5T_OPAQUE');
                H5T_STRING = H5ML.get_constant_value('H5T_STRING');
                H5T_INTEGER = H5ML.get_constant_value('H5T_INTEGER');
                H5T_FLOAT = H5ML.get_constant_value('H5T_FLOAT');
                H5T_BITFIELD = H5ML.get_constant_value('H5T_BITFIELD');
                H5T_REFERENCE = H5ML.get_constant_value('H5T_REFERENCE');
            end
            
            if ((attr_class == H5T_INTEGER) || (attr_class == H5T_FLOAT) || (attr_class == H5T_BITFIELD))
                if isvector(raw_attr_val)
                    attr_val = reshape(raw_attr_val,numel(raw_attr_val),1);
                else
                    attr_val = raw_attr_val;
                end
                return
            end
            
            attr_space = H5A.get_space(attr_id);
            
            % Perform any necessary post processing on the attribute value.
            switch (attr_class)
                
                case H5T_ENUM
                    attr_val = h5io.base.h5postprocessenums(attr_type,attr_space,raw_attr_val);
                
                case H5T_OPAQUE
                    attr_val = h5io.base.h5postprocessopaques(attr_type,attr_space,raw_attr_val);
                
                case H5T_STRING
                    attr_val = h5io.base.h5postprocessstrings(attr_type,attr_space,raw_attr_val);
                
                case H5T_REFERENCE
                    attr_val = h5io.base.h5postprocessreferences(attr_id,attr_space,raw_attr_val);
                
                otherwise
                    attr_val = raw_attr_val;
                
            end
            
        end
        function value = h5postprocessstrings(datatype, space, raw_value)
        % Strings are read as multidimensional char arrays where the leading
        % dimension's length is the HDF5 string length.  Process it such
        % that the data becomes a cell array whose dimensions match the
        % dataspace.
        
            if H5T.is_variable_str(datatype)

                % The string should already be in cell array form.  We're done.
                value = raw_value;

            else

                space_type = H5S.get_simple_extent_type(space);
                switch(space_type)
                    case H5ML.get_constant_value('H5S_SCALAR')
                        % Scalar string, turn it into a readable char array.
                        value = raw_value';

                    case H5ML.get_constant_value('H5S_NULL')
                        value = '';

                    case H5ML.get_constant_value('H5S_SIMPLE')
                        [ndims,h5_dims] = H5S.get_simple_extent_dims(space);
                        dims = fliplr(h5_dims);

                        % We have an N-dimensional string.  Turn it into a cell array of
                        % rank N.
                        if ndims == 1
                            % Vector output will always be returned as a single column.
                            value = cell(dims(1),1);
                        else
                            value = cell(dims);
                        end

                        % Each entry should be human-readable, hence the transpose
                        % operation.
                        for j = 1:numel(value)
                            value{j} = raw_value(:,j)';
                        end
                end
            end
        end
        function data = h5postprocessopaques(~,space,raw_data)
        % Opaque data is a sequence of unstructured bytes where the only piece
        % of information is the number of bytes per element.  The output here will
        % be a cell array with each cell element being an nx1 column of uint8 data.
        
            [ndims,h5_dims] = H5S.get_simple_extent_dims(space);
            dims = fliplr(h5_dims);

            if ndims == 1
                % The dataset is one-dimensional.  Force the output to be a column.
                data = cell(dims(1),1);
            else
                data = cell(dims);
            end
            for j = 1:numel(data)
                data{j} = raw_data(:,j);
            end
            
        end
        function dereferencedData = h5postprocessreferences(datasetId,dataspace,refData)
        % Reference data is post processed by grabbing what's on the other side of
        % the reference, so long as it is a dataset or a dataset region.
        
            dxpl = 'H5P_DEFAULT';

            sz = size(refData);


            if sz(1) == 8
                object_reference = true;
            else
                object_reference = false;
            end

            [ndims,h5_dims] = H5S.get_simple_extent_dims(dataspace);
            dims = fliplr(h5_dims);

            switch(ndims)
                case 0
                    dereferencedData = cell(1);
                case 1
                    dereferencedData = cell(dims(1),1);
                otherwise
                    dereferencedData = cell(dims);
            end

            % The leading dimension reflects the MATLAB length of a single reference.
            for j = 1:numel(dereferencedData)

                % See if they are valid.
                if ~any(refData(:,j))
                    error(message('MATLAB:imagesci:h5postprocessreferences:invalidReference'));
                end
                if object_reference

                    % Object reference, hopefully a dataset.
                    objId = H5R.dereference(datasetId,'H5R_OBJECT',refData(:,j));
                    objType = H5R.get_obj_type (datasetId,'H5R_OBJECT', refData(:,j));

                    if objType == H5ML.get_constant_value('H5G_DATASET')
                        dspace = H5D.get_space(objId);
                        [~,dims] =  H5S.get_simple_extent_dims(dspace);
                        if isempty(dims)
                            % dataspace is NULL, no elements
                            dereferencedData{j} = [];
                        else
                            dereferencedData{j} = H5D.read(objId,'H5ML_DEFAULT','H5S_ALL','H5S_ALL',dxpl);
                        end
                        H5S.close(dspace);
                    end

                else

                    % region reference
                    objId = H5R.dereference(datasetId,'H5R_DATASET_REGION',refData(:,j));
                    space = H5R.get_region(datasetId,'H5R_DATASET_REGION',refData(:,j));

                    npoints = H5S.get_select_npoints (space);
                    memspace = H5S.create_simple (1,npoints,[]);
                    dereferencedData{j} = H5D.read(objId,'H5ML_DEFAULT',memspace,space,dxpl);

                end
                dereferencedData{j} = squeeze(dereferencedData{j});

            end
            
        end
        function data = h5postprocessenums(datatype,space,raw_data)
        % Enumerated data is numeric, but each value is attached to a tag string,
        % the 'Value'.  The output will be a cell array where each numeric value is
        % replaced with the tag.

            [ndims,h5_dims] = H5S.get_simple_extent_dims(space);
            dims = fliplr(h5_dims);

            if ndims == 0
                % Null dataspace, just return the empty set.
                data = [];
                return;
            elseif ndims == 1
                % The dataspace is one-dimensional.  Force the output to be a column.
                data = cell(dims(1),1);
            else
                data = cell(dims);
            end
            nmemb = H5T.get_nmembers(datatype);

            for j = 1:nmemb
                Name = H5T.get_member_name(datatype,j-1);
                enum_value = H5T.get_member_value(datatype,j-1);
                idx = find(raw_data == enum_value);

                %%% Can this be done more efficiently?
                for k = 1:numel(idx)
                    data{idx(k)} = Name;
                end
            end
            
        end
        function h5Type = mlType_to_h5Type(mlObj)
        %MLTYPE_TO_H5TYPE Get an h5 type object for a matlab object

            % Get the class of the input object
            mlType = class(mlObj);

            % Switch based on MATLAB type
            switch lower(mlType)
                case 'double'
                    h5Type = H5T.copy('H5T_NATIVE_DOUBLE');
                case 'single'
                    h5Type = H5T.copy('H5T_NATIVE_FLOAT');
                case 'int64'
                    h5Type = H5T.copy('H5T_NATIVE_LONG');
                case 'uint64'
                    h5Type = H5T.copy('H5T_NATIVE_ULONG');
                case 'int32'
                    h5Type = H5T.copy('H5T_NATIVE_INT');
                case 'uint32'
                    h5Type = H5T.copy('H5T_NATIVE_UINT');
                case 'int16'
                    h5Type = H5T.copy('H5T_NATIVE_SHORT');
                case 'uint16'
                    h5Type = H5T.copy('H5T_NATIVE_USHORT');
                case 'int8'
                    h5Type = H5T.copy('H5T_NATIVE_CHAR');
                case 'uint8'
                    h5Type = H5T.copy('H5T_NATIVE_UCHAR');
                case 'char'
                    h5Type = H5T.copy('H5T_C_S1');
                    if ~isempty(mlObj)
                        % Don't do this when working with empty strings.
                        H5T.set_size(h5Type,numel(mlObj));
                    end
                    H5T.set_strpad(h5Type,'H5T_STR_NULLTERM');
                case 'cell'
                    if iscellstr(mlObj) %#ok<ISCLSTR>
                        h5Type = H5T.copy('H5T_C_S1');
                    else
                        error('%s is unsupported\n',mlType);
                    end
                otherwise
                    error('%s is unsupported\n',mlType);
            end

        end
    end
end

