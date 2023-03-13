classdef group < sd_toolbox.h5io.base
%GROUP Link to HDF5 group
    properties (Dependent)
        %GROUP_NAMES Names of groups stored in this object
        group_names;
        %DATASET_NAMES Names of datasets stored in this object
        dataset_names;
    end
    properties (Dependent, Access = private)
        %GROUPS Groups stored within this group
        groups;
        %DATASETS Datasets stored within this group
        datasets;
    end
    methods
        % Getters and setters
        function group_names = get.group_names(this)
            group_names = {};
            if ~isempty(this.groups)
                group_names = {this.groups.name}';
            end
        end
        function dataset_names = get.dataset_names(this)
            dataset_names = {};
            if ~isempty(this.datasets)
                dataset_names = {this.datasets.name}';
            end
        end
        function groups = get.groups(this)
            groups = [];
            num_objs = H5G.get_num_objs(this.objID);
            for i = 0:num_objs-1
                if H5G.get_objtype_by_idx(this.objID,i) == 0
                    name = H5G.get_objname_by_idx(this.objID,i);
                    group = sd_toolbox.h5io.group(this.objID,name);
                    if isempty(groups)
                        groups = group;
                    else
                        groups(end+1,1) = group; %#ok<AGROW>
                    end
                end
            end
        end
        function datasets = get.datasets(this)
            datasets = [];
            num_objs = H5G.get_num_objs(this.objID);
            for i = 0:num_objs-1
                if H5G.get_objtype_by_idx(this.objID,i) == 1
                    name = H5G.get_objname_by_idx(this.objID,i);
                    dataset = sd_toolbox.h5io.dataset(this.objID,name);
                    if isempty(datasets)
                        datasets = dataset;
                    else
                        datasets(end+1,1) = dataset; %#ok<AGROW>
                    end
                end
            end
        end
        % Constructor
        function this = group(parentID,link)
            
            if nargin > 1
                this.objID = H5G.open(parentID,link);
            end
            
        end
        % Methods
        function unlink(this,name)
        %UNLINK Unlink a group or dataset
            
            plist = 'H5P_DEFAULT';
            H5L.delete(this.objID,name,plist);
            
        end
        function varargout = add_group(this,name)
        %ADD_GROUP Add a group to this group
            
            % Add group
            plist = 'H5P_DEFAULT';
            gid = H5G.create(this.objID,name,plist,plist,plist);
            H5G.close(gid);
            
            % Output the group if requested
            if nargout > 0
                varargout{1} = this.get_group(name);
            end
            
        end
        function varargout = add_dataset(this,name,data)
        %ADD_DATASET Add a dataset to this group
            
            % Get data type
            type_id = this.mlType_to_h5Type(data);
            if iscellstr(data) %#ok<ISCLSTR>
                H5T.set_size(type_id,'H5T_VARIABLE');
            end
            
            % Get dimensions
            if iscellstr(data) %#ok<ISCLSTR>
                H5S_UNLIMITED = H5ML.get_constant_value('H5S_UNLIMITED');
                space_id = H5S.create_simple(1,numel(data),H5S_UNLIMITED);
                plist = H5P.create('H5P_DATASET_CREATE');
                H5P.set_chunk(plist,2); % 2 strings per chunk
            else
                dims = size(data);
                h5_dims = fliplr(dims);
                h5_maxdims = h5_dims;
                space_id = H5S.create_simple(numel(h5_dims),h5_dims,h5_maxdims);
                plist = 'H5P_DEFAULT';
            end
            
            % Create dataset
            dset_id = H5D.create(this.objID,name,type_id,space_id,plist);
            
            % Write to the dataset
            if iscellstr(data) %#ok<ISCLSTR>
                H5D.write(dset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',data);
            else
                H5D.write(dset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',data);
            end
            
            % Close objects
            H5S.close(space_id);
            H5T.close(type_id);
            H5D.close(dset_id);
            
            % Output the dataset if requested
            if nargout > 0
                varargout{1} = this.get_dataset(name);
            end
            
        end
        function print_contents(this)
            slash_inds = strfind(this.link,'/');
            if numel(this.link) > 1
                name = this.link(slash_inds(end)+1:end);
                fprintf('%s--Group: %s\n',repmat('  |',1,numel(slash_inds)),name);
            end
            for i = 1:numel(this.groups)
                this.groups(i).print_contents;
            end
            for i = 1:numel(this.datasets)
                this.datasets(i).print_contents;
            end
        end
        function group = get_group(this,groupID)
        %GET_GROUP Get a group from this object
            
            if ischar(groupID)
                group_index = find(strcmp(groupID,this.group_names));
                if isempty(group_index)
                    group_index = find(strcmpi(groupID,{this.groups.name}));
                end
                if isempty(group_index)
                    error('Group %s not found\n',groupID);
                end
            elseif isnumeric(groupID)
                group_index = groupID;
            else
                error('Group index must be numeric or char');
            end
            
            group = this.groups(group_index);
            
        end
        function dataset = get_dataset(this,datasetID)
        %GET_DATASET Get a dataset from this object
            
            if ischar(datasetID)
                dataset_index = find(strcmp(datasetID,this.dataset_names));
                if isempty(dataset_index)
                    dataset_index = find(strcmpi(datasetID,{this.datasets.name}));
                end
                if isempty(dataset_index)
                    error('Dataset %s not found\n',datasetID);
                end
            elseif isnumeric(datasetID)
                dataset_index = datasetID;
            else
                error('Dataset index must be numeric or char');
            end
            
            dataset = this.datasets(dataset_index);
            
        end
    end
end

