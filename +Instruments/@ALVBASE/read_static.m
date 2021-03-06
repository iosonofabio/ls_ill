function [sls_point RawData] = read_static(self,path_standard, path_solvent, path_file, protein_conc, dn_over_dc, start_index, end_index, count_number, varargin)
    %input: (path_standard, path_solvent, path_file, protein_conc,
    %dn_over_dc, start_index {autosave file} , end_index {autosave file})
    %
    %read and calculate data for static light scattering, giving as input
    %standard and water .tol files, as well as the autosave path (without dddd.ASC)
    % and protein concentration, differential index of refraction. 
    % furthermore start_index and end_index are the file indices which to load
    %
    %output : [Point SlsData]
    %SlsData is AngleData class array with single file-data info
%******************************************************************************
% Written By: Daniel Soraruf
% last change : 19/02/2012
%******************************************************************************
    %------------------------------------------------------------------------------
    % get solvent and standard data
    %------------------------------------------------------------------------------
    solvent  = self.read_tol_file(path_solvent);
    standard = self.read_tol_file(path_standard);
    index    = 0;
    point(end_index - start_index + 1) = struct('scatt_angle', 0, 'count_rate', 0, 'monitor_intensity', 0, 'error_count_rate', 0);
    %------------------------------------------------------------------------------
    % get data from autosave ALV files
    %------------------------------------------------------------------------------
    if path_file(1) == '~'
        if ispc %not tested
            homepath = winqueryreg('HKEY_CURRENT_USER',...
                ['Software\Microsoft\Windows\CurrentVersion\' ...
                'Explorer\Shell Folders'],'Personal');
        else
            homepath = getenv('HOME');
        end
            path_file     = [homepath path_file(2:end)];
    end
    for i = start_index : end_index
        flag = true;
        j = 1;
        while flag
            index = index + 1;
            file  = self.generate_filename(path_file, i, j);
             % [count_rate1 count_rate2 point(index).monitor_intensity point(index).scatt_angle point(index).temperature datetime]...
             % = self.read_static_from_autosave_fast(file);
             [count_rate1 count_rate2 point(index).monitor_intensity point(index).scatt_angle point(index).temperature datetime]...
             = self.read_static_from_autosave(file);
            point(index).count_rate       = count_rate1 + count_rate2;
            point(index).error_count_rate = sqrt(count_rate1 * 1000) + sqrt(count_rate2 * 1000);
            point(index).file_index       = [i j];
            point(index).datetime_raw     = datetime;
            if j >= count_number
                flag = false;
            else
                j = j + 1;
            end
        end
    end
    regexpstr = Instruments.get_datetime_format(point(1).datetime_raw);
    if ~isempty(regexpstr)
        for i = 1 : length(point)
            point(i).datetime = datenum(point(i).datetime_raw, regexpstr);
        end
        datetime_bool = true;
    else
        for i = 1 : length(point)
            point(i).datetime = false;
        end
        datetime_bool = false;
        warning('wrong format regular expression for datetime extraction: change Instrument.get_datetime_format to correct format please')
    end
    %[KcR] = calc_kc_over_r(scatt_angle, standard, solvent,cr_mean,0.001, Imean);
    % find all angles in file
    a = unique([point.scatt_angle]);
    % sort them ( to be consistent with the program generated file)
    angles = sort(a);
    % preallocate memory
    SlsData = SLS.AngleData.empty(length(angles),0);
    angle_tolerance = 1e-3;
    for index = 1 : length(angles)
        SlsData(index) = SLS.AngleData(angles(index));
        for index_1 = 1 : length(point);
            % save data at ONE ANGLE in SlsData
            if abs(point(index_1).scatt_angle - angles(index)) < angle_tolerance
                SlsData(index).add(point(index_1));
            end
        end
    end
    %--------------------------------------------------------------------------
    % calc Kc over R
    %--------------------------------------------------------------------------
    for i = 1 : length(SlsData)
        SlsData(i).calc_kc_over_r(standard, solvent, protein_conc, dn_over_dc,self);
        %SlsData(i).show_cr();
    end
    %--------------------------------------------------------------------------
    % Save into SLS.Point array
    %--------------------------------------------------------------------------
    %disp(SlsData(1).KcR)
    for i = 1 : length(SlsData)
        sls_point(i)              = SLS.Point;
        sls_point(i).Instrument   = self;
        sls_point(i).T            = SlsData(i).mean_temperature;
        sls_point(i).Angle        = SlsData(i).scatt_angle;
        sls_point(i).KcR_raw      = SlsData(i).KcR;
        sls_point(i).dKcR_raw     = SlsData(i).dKcR;
        sls_point(i).Imon         = SlsData(i).mean_monitor_intensity;
        sls_point(i).dImon        = SlsData(i).error_mean_monitor_intensity;
        sls_point(i).datetime_raw = SlsData(i).count(1).datetime_raw;
        if datetime_bool
            sls_point(i).datetime     = mean([SlsData(i).count(1:end).datetime]);
        end
    end
    RawData.SlsData  = SlsData;
    RawData.solvent  = solvent;
    RawData.standard = standard;
end
