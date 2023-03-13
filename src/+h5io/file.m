classdef file < h5io.group
%FILE Access to an HDF5 file
    properties (Dependent)
        %FILESIZE File size in bytes
        filesize;
        %FREESPACE File free space in bytes
        freespace;
        %MDC_CONFIG Metadata cache config
        mdc_config;
        %MDC_HIT_RATE Metadata cache hit rate
        mdc_hit_rate;
        %MDC_SIZE Metadata cache size
        mdc_size;
        %FILENAME File name
        filename;
    end
    methods
        % Getters and setters
        function filesize = get.filesize(this)
            filesize = H5F.get_filesize(this.objID);
        end
        function freespace = get.freespace(this)
            freespace = H5F.get_freespace(this.objID);
        end
        function mdc_config = get.mdc_config(this)
            mdc_config = H5F.get_mdc_config(this.objID);
        end
        function set.mdc_config(this,mdc_config)
            H5F.set_mdc_config(this.objID,mdc_config);
        end
        function mdc_hit_rate = get.mdc_hit_rate(this)
            mdc_hit_rate = H5F.get_mdc_hit_rate(this.objID);
        end
        function mdc_size = get.mdc_size(this)
            mdc_size = H5F.get_mdc_size(this.objID);
        end
        function filename = get.filename(this)
            filename = H5F.get_name(this.objID);
        end
        % Constructor / Destructor
        function this = file(path,access)
        %FILE Class constructor
            
            % Default access level is read-only
            if nargin < 2
                access = 'r';
            end
            
            % Check if the file exists
            file_exists = exist(path,'file');
            
            % Ensure it's an HDF5 file
            if file_exists
                if H5F.is_hdf5(path) == 0
                    error('Existing file is not an HDF5 file:\n%s\n',path);
                end
            end
            
            % Different opening method based on access level
            switch access
                
                % Open existing for reading
                case 'r'
                    h5_access = 'H5F_ACC_RDONLY';
                    if ~file_exists
                        error('File not found: %s\n',path);
                    end
                    this.objID = H5F.open(path,h5_access,'H5P_DEFAULT');
                    
                % Create new file or overwrite old and open with read/write access
                case 'w'
                    h5_access = 'H5F_ACC_TRUNC';
                    fcpl = H5P.create('H5P_FILE_CREATE');
                    fapl = H5P.create('H5P_FILE_ACCESS');
                    this.objID = H5F.create(path,h5_access,fcpl,fapl);
                    
                % Open existing with read/write access
                case 'a'
                    h5_access = 'H5F_ACC_RDWR';
                    if ~file_exists
                        error('File not found: %s\n',path);
                    end
                    try
                        this.objID = H5F.open(path,h5_access,'H5P_DEFAULT');
                    catch
                        error('Access denied: %s\n',path);
                    end
                    
                otherwise
                    error('Access level %s is unsupported\n',access);
            end
            
        end
        function delete(this)
        %DELETE Class destructor
            
            % Delete reference to the obj if it's still valid
            if ~isempty(this.objID)
                if H5I.is_valid(this.objID)
                    H5F.close(this.objID);
                end
            end
            this.objID = [];
            
        end
        % Methods
        function reopen(this)
        %REOPEN Reopen HDF5 file
            
            % Call reopen function
            this.objID = H5F.reopen(this.objID);
            
        end
        function print_contents(this)
            fprintf('File: %s\n',this.filename);
            print_contents@h5io.group(this);
        end
    end
end

