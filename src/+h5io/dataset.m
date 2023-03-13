classdef dataset < sd_toolbox.h5io.base
%DATASET dataset access for HDF5 file    
    properties
        %DIMS Matrix dimensions
        dims
    end
    methods
        % Getters and setters
        function dims = get.dims(this)
            space = H5D.get_space(this.objID);
            [~, dims] = H5S.get_simple_extent_dims(space);
            dims = fliplr(dims);
            H5S.close(space);
        end
        % Constructor
        function this = dataset(parentID,link)
            
            this.objID = H5D.open(parentID,link);
            
        end
        % Methods
        function data = get_data(this)
            data = H5D.read(this.objID);
        end
        function print_contents(this)
            slash_inds = strfind(this.link,'/');
            if numel(this.link) > 1
                name = this.link(slash_inds(end)+1:end);
                fprintf('%s--Dataset: %s',repmat('  |',1,numel(slash_inds)),name);
                if numel(this.dims) == 1
                    fprintf(' [%d]',this.dims);
                elseif numel(this.dims) == 2
                    fprintf(' [%d X %d]',this.dims(1),this.dims(2));
                end
                fprintf('\n');
            end
        end
    end
end

