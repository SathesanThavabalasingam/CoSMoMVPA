function ds=cosmo_meeg_dataset(filename, varargin)
% Returns a dataset structure based on MEEG data
%
% ds=cosmo_meeg_dataset(filename, varargin)
%
% Inputs:
%   filename          filename of MEEG data to be loaded. Currently
%                     supported are files with extensions:
%                       .mat :        FieldTrip time-locked or
%                                     time-frequency  data at  either the
%                                     sensor or source level.
%                       .txt :        exported EEGLab with timelocked data.
%                       .daterp       time-locked      }
%                       .icaerp       ICA time-locked  } EEGLab
%                       .dattimef     time-freq        }
%                       .icatimef     ICA time-freq    }
%                     Alternatively it can be a FieldTrip or EEGLab struct
%                     with time-locked or time-frequency data
%   'targets', t      Px1 targets for P samples; these will be stored in
%                     the output as ds.sa.targets (optional)
%   'chunks', c       Px1 chunks for P samples; these will be stored in the
%                     the output as ds.sa.chunks (optional)
%   'data_field', f   For MEEG source dataset with multiple data fields
%                     (such as 'pow' and 'mom'), this sets which data field
%                     is used. (only for source data)
%   'trials', idx     Mx1 array with indices of trials to load (optional).
%                     If not provided then all trials are loaded. The
%                     output has a .samples field with the number of rows
%                     equal to numel(idx).
%
% Returns:
%   ds                dataset struct with the following fields
%     .samples        PxQ for P samples and Q features.
%     .sa.targets     Px1 sample targets (if provided)
%     .sa.chunks      Px1 sample chunks (if provided)
%     .a
%       .hdr_{F}           header information for format F. Currently
%                          F is always 'ft'.
%       .meeg
%         .sample_field   name of sample field. One of 'fourierspctrm',
%                         'powspctrm', or 'trial'.
%         .samples_type   'timelock' or 'timefreq'.
%         .samples_label  Usually 'rpt'; or the first field of .dimord
%                         for FieldTrip data
%       .dim
%         .labels     1xS cell struct with labels for the feature
%                     dimensions of the input. Usually this is
%                     {'chan','time'} or {'chan','freq','time'}.
%         .values     1xS cell struct with values associated with .labels.
%                     If the K-th value has N_K values, this means that
%                     the feature dimension .labels{K} takes the
%                     values in .values{K}. For example, if
%                     .labels{1}=='chan', then .values{1} contains the
%                     channel labels.
%     .fa
%       .{D}          if D==a.fdim.labels{K} is the label for the K-th
%                     feature dimension, then .{D} contains the
%                     indices referencing a.fdim.values. Thus, all values in
%                     .{D} are in the range 1:N_K if a.fdim.values{K} has
%                     N_K values, and the J-th feature has dimension value
%                     .dim.values{K}(.{D}(J)) in the K-th dimension.
%
% Notes:
%  - The resulting dataset can be mapped back to MEEG format using
%    cosmo_map2meeg.
%  - if the input contains data from a single sample (such as an average)
%    the .sample_field is set to .trial, and mapping back to MEEG format
%    adds a singleton dimension to the .trial data output field.
%  - For single-subject MVPA of single trials using data preprocessed with
%    FieldTrip, consider setting, depending on the data type:
%       * timelock (ft_timelockanalysis): cfg.keeptrials = 'yes'
%       * timefreq (ft_timefreqanalysis): cfg.keeptrials = 'yes'
%       * source   (ft_sourceanalysis)  : cfg.keeptrials = 'yes' *and*
%                                                   cfg.rawtrials = 'yes'
%  - Most MVPA applications require that .sa.targets (experimental
%    condition of each sample) and .sa.chunks (partitioning of the samples
%    in independent sets) are set, either by using this function or
%    manually afterwards.
%  - If the input is a FieldTrip struct with a field .trialinfo, then this
%    field is present in .sa.trialinfo. Depending on the contents of
%    .trialinfo, this could be used to specify conditions in each trial.
%    For example, if the third column of .trialinfo contains an integer
%    specifying the condition of each trial, after running this function
%    one can do
%
%       ds.sa.targets=ds.sa.trialinfo(:,3)
%
%    to set the trial conditions.
%  - Implementation note: when loading EEGLAB data from a file, using this
%    option means that different parts of the file are with different
%    'load' commands. The advantage is that significant less memory is
%    needed compared to when the full dataset is loaded first and then
%    sliced. The disadvantage is that loaded may take longer, because the
%    file is opened and closed multiple times.
%    Such memory reductions are currently not implemented for FieldTrip
%    data, as FieldTrip's data structures do not allow for such memory
%    usage reductions.

%
% See also: cosmo_map2meeg
%
% #   For CoSMoMVPA's copyright information and license terms,   #
% #   see the COPYING file distributed with CoSMoMVPA.           #

    % Input parsing stuff

    defaults=struct();
    defaults.targets=[];
    defaults.chunks=[];

    params = cosmo_structjoin(defaults, varargin);

    if cosmo_check_dataset(filename,'meeg',false)
        % it is already a dataset
        ds=filename;
    else
        % get image format and verify it is supported
        img_format=get_img_format(filename);
        supported_image_formats=get_supported_image_formats();

        % check externals
        cosmo_check_external(supported_image_formats.(img_format).externals);

        % get the reader
        reader=supported_image_formats.(img_format).reader;

        % read the dataset
        ds=reader(filename, params);
    end

    % set targets and chunks
    ds=set_vec_sa(ds,'targets',params.targets);
    ds=set_vec_sa(ds,'chunks',params.chunks);


    % check consistency
    cosmo_check_dataset(ds,'meeg');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% general helper functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ds=set_vec_sa(ds, label, values)
    if isempty(values)
        return;
    end
    if numel(values)==1
        nsamples=size(ds.samples,1);
        values=repmat(values,nsamples,1);
    end
    ds.sa.(label)=values(:);


function img_format=get_img_format(filename)
    % helper functgion to detect image format based on filename.
    % uses 'get_supported_image_formats'.
    img_formats=get_supported_image_formats();

    fns=fieldnames(img_formats);
    for k=1:numel(fns)
        fn=fns{k};

        img_spec=img_formats.(fn);
        if img_spec.file_matcher(filename)
            img_format=fn;
            return
        end
    end
    error('Unknown image format');

function img_formats=get_supported_image_formats()
    % helper function to return the image format based on the filename
    img_formats=struct();

    % helper function to see if a filename ends with a certain string.
    % uses currying - who doesn't like curry?
    ends_with=@(ext) @(fn) ischar(fn) && ...
                        isempty(cosmo_strsplit(fn,ext,-1));
    ends_with_any=@(exts) @(fn) ischar(fn) && any(...
                            cellfun(@(x)isempty(...
                                        cosmo_strsplit(fn,x,-1)),exts));

    % eeglab txt files
    img_formats.eeglab_txt.file_matcher=ends_with('.txt');
    img_formats.eeglab_txt.reader=@read_eeglab_txt;
    img_formats.eeglab_txt.externals={};

    img_formats.eeglab.file_matcher=ends_with_any({'.daterp',...
                                                   '.icaerp',...
                                                   '.dattimef',...
                                                   '.icatimef'});
    img_formats.eeglab.reader=@read_eeglab;
    img_formats.eeglab.externals={};

    img_formats.eeglab_struct.file_matcher=@is_eeglab_struct;
    img_formats.eeglab_struct.reader=@convert_eeglab_struct;
    img_formats.eeglab_struct.externals={};



    % fieldtrip
    % XXX any .mat file is currently assumed to be a fieldtrip struct
    img_formats.ft.file_matcher=ends_with('.mat');
    img_formats.ft.reader=@read_ft;
    img_formats.ft.externals={};

    % fieldtrip matlab struct
    img_formats.ft_struct.file_matcher=@(x) is_ft_struct(x);
    img_formats.ft_struct.reader=@convert_ft;
    img_formats.ft_struct.externals={};


function ds=posthoc_slice_dataset_if_necessary(ds,opt)
    if ~isfield(opt,'trials')
        return;
    end

    trial_idx=opt.trials;
    verify_trial_params(size(ds.samples,1),trial_idx);
    ds=cosmo_slice(ds,trial_idx);

function verify_trial_params(nsamples,trial_idx)
    if ~isnumeric(trial_idx)
        error('.trials option must be numeric');
    end

    bad_msk=trial_idx<1 | ...
                trial_idx>nsamples | ...
                round(trial_idx)~=trial_idx;

    if any(bad_msk)
        bad_pos=find(bad_msk,1);
        error(['.trials option has illegal value at position %d; '...
                'all values must be in (1:%d)'],...
                bad_pos,nsamples);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fieldtrip helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ds=read_ft(filename, opt)
    % reads it from a .mat data file
    ft=importdata(filename);
    ds=convert_ft(ft, opt);


function ds=convert_ft(ft, opt)
    [data, samples_field, fdim]=get_ft_data(ft, opt);

    ds=cosmo_flatten(data, fdim.labels, fdim.values,2,...
                                'matrix_labels',get_ft_matrix_labels());
    ds.a.meeg.samples_field=samples_field;

    if is_ft_source_struct(ft)
        ds=apply_ft_source_inside(ds,fdim.labels,fdim.values,...
                                        ft.inside);
        ds.a.meeg.dim=ft.dim;
    end

    nsamples=size(ds.samples,1);
    ft_fields={'rpt','trialinfo','cumtapcnt'};
    ds.sa=copy_fields_for_matching_sample_size(ft,nsamples,ft_fields);

    ds=posthoc_slice_dataset_if_necessary(ds,opt);


function [data,samples_field,fdim]=get_ft_data(ft,opt)
    [data, samples_field]=get_data_ft(ft,opt);
    [dim_labels,ft_dim_labels]=get_ft_dim_labels(ft, samples_field);

    nlabels=numel(dim_labels);
    dim_values=cell(nlabels,1);
    matrix_labels=get_ft_matrix_labels();
    for k=1:nlabels
        label=ft_dim_labels{k};
        value=ft.(label);
        if cosmo_match({label},matrix_labels)
            dim_values{k}=value';
        else
            dim_values{k}=value(:)';
        end
    end

    fdim.labels=dim_labels;
    fdim.values=dim_values;

    if is_ft_source_struct(ft)
        fdim=add_ft_mom_field_if_present(fdim, samples_field, size(data));
        [data,fdim]=fix_ft_lcmv_if_necessary(data,fdim);
    end


function [data,fdim]=fix_ft_lcmv_if_necessary(data,fdim)
    % FT LCMV does something weird for average data; the .avg.pow field
    % is 1xNCHAN for a NCHAN x NTIME field.
    % To address this:
    % - reshape the data
    % - average the time field
    dim_labels=fdim.labels;
    data_size=size(data);

    pos_pos=find(cosmo_match(dim_labels,'pos'));
    if ~isempty(pos_pos) && ... % has pos field
                pos_pos<numel(dim_labels)

        npos=size(fdim.values{pos_pos},2);
        next_dim_pos=pos_pos+1;

        if data_size(pos_pos+1)==1 && data_size(next_dim_pos+1)==npos
            new_data_size=data_size;

            % fix with next dimension
            new_data_size(pos_pos+1)=npos;
            new_data_size(next_dim_pos+1)=1;

            data=reshape(data,new_data_size);

            % the next dimension (typically time) is averaged if
            % necessary
            next_dim_value=fdim.values{next_dim_pos};
            if numel(next_dim_value)~=1
                fdim.values{next_dim_pos}=mean(next_dim_value);
            end

        end
    end



function fdim=add_ft_mom_field_if_present(fdim, samples_field, size_data)
    % insert .mom field for source struct
    samples_field_split=cosmo_strsplit(samples_field,'.');
    has_mom=numel(samples_field_split)==2 && ...
                    strcmp(samples_field_split{2},'mom');
    if has_mom
        ndim=size_data(3);
        fdim.labels=[fdim.labels(1);...
                                {'mom'};...
                                fdim.labels(2:end)];
        switch ndim
            case 1
                values={'xyz'};
            case 3
                values={'x','y','z'};
            otherwise
                error('Unsupported number of dimensions for %s: %d',...
                            samples_field,ndim);
        end
        fdim.values=[fdim.values(1);...
                                {values};...
                                fdim.values(2:end)];
    end


function labels=get_ft_matrix_labels()
    labels={'pos'};

function [cosmo_dim_labels,ft_dim_labels]=get_ft_dim_labels(ft, ...
                                                        samples_field)
    cosmo_ft_dim_labels={ 'pos','pos';...
                          'chan','label';...
                          'freq','freq';...
                          'time','time'};

    is_source=is_ft_source_struct(ft);

    if is_source==isfield(ft,'dimord')
        error('Weird fieldtrip data: .pos and .dimord are not compatible');
    end

    if is_source
        % source data
        keys=fieldnames(ft);
        labels_msk=cosmo_match(cosmo_ft_dim_labels(:,2),keys);
    else


        dimord_labels=cosmo_strsplit(ft.dimord,'_');

        sample_field=get_sample_dimord_field(ft);
        sample_msk=cosmo_match(dimord_labels, sample_field);

        dimord_labels_without_sample=dimord_labels(~sample_msk);

        labels_msk=cosmo_match(cosmo_ft_dim_labels(:,1),...
                                dimord_labels_without_sample);
    end

    ft_dim_labels=cosmo_ft_dim_labels(labels_msk,2);
    cosmo_dim_labels=cosmo_ft_dim_labels(labels_msk,1);





function sample_field=get_sample_dimord_field(ft)
    sample_field='';

    sample_dimord_fields={'rpt','trial'};
    if isfield(ft,'dimord')
        ft_dimord_fields=cosmo_strsplit(ft.dimord,'_');
        msk=cosmo_match(ft_dimord_fields,sample_dimord_fields);
        if any(msk)
            assert(sum(msk)==1);
            sample_field=sample_dimord_fields{msk};
        end
    end


function sa=copy_fields_for_matching_sample_size(ft,nsamples,keys)
    n=numel(keys);

    sa=struct();
    for k=1:n
        key=keys{k};
        if isfield(ft,key)
            value=ft.(key);
            if size(value,1)==nsamples
                sa.(key)=value;
            end
        end
    end







function ds=apply_ft_source_inside(ds,dim_labels,dim_values,ft_inside)
    ndim=numel(dim_labels);
    dim_sizes=cellfun(@numel,dim_values);

    pos_idx=find(cosmo_match(dim_labels,'pos'),1);
    assert(~isempty(pos_idx),['this function should only be called '...
                                'with source datasets']);

    if isnumeric(ft_inside)
        pos=ds.a.fdim.values{pos_idx};
        [three,npos]=size(pos);
        assert(three==3);
        inside_mask=false(npos,1);
        inside_mask(ft_inside)=true;
    elseif islogical(ft_inside)
        inside_mask=ft_inside;
    else
        error('.inside must either be numeric or logical');
    end


    inside_vec_size=[1 ones(1,ndim)];
    inside_vec_size(1+pos_idx)=numel(inside_mask);
    inside_array_vec=reshape(inside_mask, inside_vec_size);

    other_dim_size=[1 dim_sizes(:)'];
    other_dim_size(1+pos_idx)=1;

    inside_array=repmat(inside_array_vec,other_dim_size);
    inside_ds=cosmo_flatten(inside_array, dim_labels, dim_values,2,...
                                         'matrix_labels',{'pos'});
    ds=cosmo_slice(ds,inside_ds.samples,2);




function [data, sample_field]=get_data_ft(ft,opt)
    if is_ft_source_struct(ft)
        [data, sample_field]=get_source_data_ft(ft, opt);
    else
        [data, sample_field]=get_sensor_data_ft(ft);
    end

function [data, sample_field]=get_source_data_ft(ft, opt)
    main_fields={'trial','avg'};
    sub_fields={'pow','mom'};

    msk_main=cosmo_match(main_fields,fieldnames(ft));
    switch sum(msk_main)
        case 0
            error('No data found in source struct');

        case 1
            % ok

        otherwise
            error('Multiple data fields found in source struct');
    end

    main_field=main_fields{msk_main};
    main_data=ft.(main_field);

    sub_field_option='data_field';
    if isfield(opt,sub_field_option)
        sub_field=opt.(sub_field_option);
    else
        msk_sub=cosmo_match(sub_fields,fieldnames(main_data));

        switch sum(msk_sub)
            case 0
                error('No data found in .%s source struct', main_field);

            case 1
                sub_field=sub_fields{msk_sub};

            otherwise
                error(['Multiple data fields found in .%s source '...
                        'struct: ''%s''. To select one of these, use '...
                        'the ''%s'' option'],...
                        main_field,...
                        cosmo_strjoin(sub_fields(msk_sub),''', '''),...
                        sub_field_option);
        end
    end

    data=extract_source_data_array_ft(main_data, sub_field);
    sample_field=sprintf('%s.%s',main_field,sub_field);

function data=extract_source_data_array_ft(main_data, sub_field)
    nsamples=numel(main_data);
    first_data=main_data(1).(sub_field);
    data_cell=cell(nsamples,1);


    switch sub_field
        case 'mom'
            npos=numel(first_data);
            data_inside_pos=find(~cellfun(@isempty,first_data));
            ninside=numel(data_inside_pos);

            [nmom, nfeatures]=size(first_data{data_inside_pos(1)});

            data_arr_empty=NaN(1,npos,nmom,nfeatures);

            for j=1:nsamples
                data_cell_cell=main_data(j).(sub_field);
                data_arr=data_arr_empty;

                for k=1:ninside
                    pos=data_inside_pos(k);
                    data_arr(1,pos,:,:)=data_cell_cell{pos};
                end

                data_cell{j}=data_arr;
            end


        case 'pow'
            feature_size=size(first_data);

            for j=1:nsamples
                data_arr=main_data(j).(sub_field);
                data_cell{j}=reshape(data_arr,[1 feature_size]);
            end

        otherwise
            error('not supported sub_field: %s', sub_field);
    end

    data=cat(1,data_cell{:});




function [data, sample_field]=get_sensor_data_ft(ft)
    % order precedence: if .trial and .avg both exist, take .trial
    sample_fields_in_order={'trial',...
                            'fourierspctrm','powspctrm','avg'};
    msk=cosmo_match(sample_fields_in_order, fieldnames(ft));

    if ~any(msk)
        error('no data field found in sensor data struct');
    end

    i=find(msk,1);
    sample_field=sample_fields_in_order{i};

    data=ft.(sample_field);

    if isempty(get_sample_dimord_field(ft))
                        % no 'rpt_...'
        data=reshape(data,[1 size(data)]);
    end



function tf=is_ft_source_struct(ft)
    tf=isstruct(ft) && isfield(ft,'pos') && isfield(ft,'inside');

function tf=is_ft_sensor_struct(ft)
    tf=isfield(ft,'dimord') && isfield(ft,'label');

function tf=is_ft_struct(ft)
    tf=is_ft_source_struct(ft) || is_ft_sensor_struct(ft);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eeglab struct helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function tf=is_eeglab_struct(s)
    tf=isstruct(s) && ...
            isfield(s,'times') && ...
            isfield(s,'datatype');


function ds=read_eeglab(fn,opt)
    if isfield(opt,'trials')
        % can have significant reduction in memory requirements
        % at the expense of loading different parts of the same file
        % multiple times.
        s=eeglab_load_with_trials(fn,opt.trials);
        opt=rmfield(opt,'trials');
    else
        s=load(fn,'-mat');
    end
    ds=convert_eeglab_struct(s,opt);

function s=eeglab_load_with_trials(fn,trial_idx)
    % can save memory by loaded each channel seperately
    s_minimal=load(fn,'-mat','datatype');
    has_freq=helper_eeglab_get_freq_info(s_minimal);

    w=whos('-file',fn);
    s_surrogate=struct();
    for k=1:numel(w)
        s_surrogate.(w(k).name)=[];
    end

    [chan_prefix,chan_suffix]=eeglab_get_chan_pre_suffix(s_surrogate);
    [chan_labels]=eeglab_get_chan_labels(s_surrogate,...
                                    chan_prefix,chan_suffix);
    other_labels=setdiff({w.name},chan_labels);
    assert(numel(other_labels)<numel(w));

    s=load(fn,'-mat',other_labels{:});
    n_chan=numel(chan_labels);
    for k=1:n_chan
        label=chan_labels{k};
        data_struct=load(fn,'-mat',label);
        data=data_struct.(label);

        sliced_data=helper_eeglab_slice_chan(data,trial_idx,has_freq);
        s.(label)=sliced_data;
    end


function result=helper_eeglab_slice_chan(data, trial_idx, has_freq)
    assert(islogical(has_freq));

    if has_freq
        trial_dim=3;
    else
        trial_dim=1;
    end

    % ensure enough trials
    n_trials=size(data,trial_dim);
    verify_trial_params(n_trials,trial_idx);

    if has_freq
        result=data(:,:,trial_idx);
    else
        assert(numel(size(data))<=2);
        result=data(trial_idx,:);
    end

function [has_freq,freq_label,freq_values]=helper_eeglab_get_freq_info(s)
    samples_type=eeglab_get_samples_type(s);
    has_freq=strcmp(samples_type,'timefreq');
    if nargout<=1
        return;
    end

    if has_freq
        freq_label={'freq'};
        freq_values={s.freqs};
    else
        freq_label={};
        freq_values={};
    end



function ds=convert_eeglab_struct(s, opt)
    samples_type=eeglab_get_samples_type(s);
    [has_freq,freq_label,freq_values]=helper_eeglab_get_freq_info(s);
    freq_size=cellfun(@numel,freq_values);

    [chan_prefix,chan_suffix]=eeglab_get_chan_pre_suffix(s);
    [eeglab_labels,chan_values]=eeglab_get_chan_labels(...
                                        s,chan_prefix,chan_suffix);
    n_chan=numel(chan_values);

    if isfield(s,'chanlabels')
        assert(numel(s.chanlabels)==n_chan);
    end

    time_values=s.times;
    n_time=numel(time_values);

    data_cell=cell(n_chan,1);
    for k=1:n_chan
        key=eeglab_labels{k};
        value=s.(key);

        if has_freq
            % it seems that for freq data, single trial data is the last
            % dimension, whereas for erp data, single trial data is the first
            % dimension. In any case we want to make single trial data the
            % first dimension
            has_trial_dim=size(value,3)~=1;
            if has_trial_dim
                value=shiftdim(value,2);
            else
                value=shiftdim(value,-1); % insert singleton dimension
            end
        end

        n_samples=size(value,1);
        size_chan_singleton=[n_samples,1,[freq_size],n_time];

        value_rs=reshape(value,size_chan_singleton);
        data_cell{k}=value_rs;
    end


    data=cat(2,data_cell{:});
    ds=cosmo_flatten(data,[{chan_prefix},freq_label,{'time'}],...
                          [{chan_values},freq_values,{time_values}]);

    ds.sa=struct();
    ds.a.meeg.samples_field='trial';
    ds.a.meeg.samples_type=samples_type;
    ds.a.meeg.samples_label='rpt';

    ds.a.meeg.parameters=s.parameters;

    ds=posthoc_slice_dataset_if_necessary(ds,opt);


function [chan_prefix,chan_suffix]=eeglab_get_chan_pre_suffix(s)
    keys=fieldnames(s);

    numeric_infix='1';
    pat=['^(\D+)' numeric_infix '([\D_]*$)'];
    matches=regexp(keys,pat,'once','tokens');

    match_idx=find(~cellfun(@isempty,matches));

    if numel(match_idx)~=1
        error('no (unique) channel found ending at ''1''');
    end

    unique_match=matches{match_idx};
    chan_prefix=unique_match{1};
    chan_suffix=unique_match{2};



function [eeglab_labels,cosmo_labels]=eeglab_get_chan_labels(...
                                s,chan_prefix,chan_suffix)

    make_eeglab_label=@(idx)sprintf('%s%d%s',chan_prefix,idx,chan_suffix);
    % see how many labels there are
    count=0;
    while true
        label=make_eeglab_label(count+1);
        if ~isfield(s,label)
            break
        end
        count=count+1;
    end

    idxs=1:count;

    eeglab_labels=arrayfun(make_eeglab_label,idxs,'UniformOutput',false);
    if strcmp(chan_prefix,'comp')
        assert(~isfield(s,'chanlabels'));
        make_comp_label=@(idx)sprintf('comp%d',idx);
        cosmo_labels=arrayfun(make_comp_label,idxs,'UniformOutput',false);
    else
        cosmo_labels=s.chanlabels;
    end






function samples_type=eeglab_get_samples_type(s)
    mapping={'erp','timelock';...
            'timef','timefreq'};
    for k=1:size(mapping,1)
        row=mapping(k,:);
        if strcmp(lower(s.datatype),row{1})
            samples_type=row{2};
            return;
        end
    end

    error('unsupported datatype mapping ''%s''',s.datatype);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eeglab txt helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ds=read_eeglab_txt(fn, opt)
    % reads eeglab time series data. returns data in fieldtrip-like format
    fid=fopen(fn);

    header_line=fgetl(fid); % read header
    chan_labels=cosmo_strsplit(header_line,'\t');
    chan_labels=chan_labels(2:(end-1)); % omit first & last bogus element

    nchan=numel(chan_labels);
    data_pat=cosmo_strjoin(repmat({'%n'},1,nchan+1),' ');

    % read data from file
    cell_data=textscan(fid,data_pat);

    % check all data was read
    neg_one=fgetl(fid);
    if neg_one~=-1
        error('Could not read all data from %s', fn);
    end

    %%%%%%%%%%%%%%%
    % data consistency checks

    % timepoints are in the first column, data in other columns
    timepoints=cell_data{1};
    nrows=numel(timepoints);

    [unused,t_trial]=cosmo_index_unique(timepoints);
    ntime=numel(t_trial);

    if mod(nrows,ntime)~=0 || ...
                ~all(all(bsxfun(@eq,reshape(timepoints,ntime,[]),...
                                  t_trial)))
        error('Data not contiguous or unexpected order of time points');
    end

    % number of trials
    ntrial=nrows/ntime;


    %%%%%%%%%%%%%%%
    % put the data in 3D array
    data=zeros(ntrial,nchan,ntime);
    for chan=1:nchan
        chan_data=cell_data{chan+1}; % skip first column as it has timepoints
        data(:,chan,:)=reshape(chan_data,ntime,ntrial)';
    end

    %%%%%%%%%%%%%%%
    % flatten and make it a dataset
    % (convert miliseconds to seconds along the way)
    dim_labels={'chan';'time'};
    dim_values={chan_labels(:)';.001*t_trial(:)'};

    % make a dataset
    ds=cosmo_flatten(data, dim_labels, dim_values);

    % set datatype to timelock-ish in fieldtrip-compatible way
    ds.a.meeg.samples_field='trial';
    ds.a.meeg.samples_type='timelock';
    ds.a.meeg.samples_label='rpt';

    % set sample info
    ds.sa.(ds.a.meeg.samples_label)=(1:ntrial)';

    ds=posthoc_slice_dataset_if_necessary(ds,opt);


