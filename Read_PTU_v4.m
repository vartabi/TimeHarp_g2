function [Raw_stamps, time_stamps, ch, n_ovfl, filename] = Read_PTU_v4(save_csv,varargin)

if nargin ==0
    save_csv=0;
end
    % some constants
    tyEmpty8      = hex2dec('FFFF0008');
    tyBool8       = hex2dec('00000008');
    tyInt8        = hex2dec('10000008');
    tyBitSet64    = hex2dec('11000008');
    tyColor8      = hex2dec('12000008');
    tyFloat8      = hex2dec('20000008');
    tyTDateTime   = hex2dec('21000008');
    tyFloat8Array = hex2dec('2001FFFF');
    tyAnsiString  = hex2dec('4001FFFF');
    tyWideString  = hex2dec('4002FFFF');
    tyBinaryBlob  = hex2dec('FFFFFFFF');
    % RecordTypes
    rtTimeHarp260PT2 = hex2dec('00010206');% (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $06 (TimeHarp260P)

    % Globals for subroutines
    global fid
    global TTResultFormat_TTTRRecType;
    global TTResult_NumberOfRecords; % Number of TTTR Records in the File;
    global MeasDesc_Resolution;      % Resolution for the Dtime (T3 Only)
    global MeasDesc_GlobalResolution;

    TTResultFormat_TTTRRecType = 0;
    TTResult_NumberOfRecords = 0;
    MeasDesc_Resolution = 0;
    MeasDesc_GlobalResolution = 0;

    % start Main program
    [filename, pathname]=uigetfile('*.ptu', 'T-Mode data:');
    fid=fopen([pathname filename]);

%     fprintf(1,'\n');
    Magic = fread(fid, 8, '*char');
    if not(strcmp(Magic(Magic~=0)','PQTTTR'))
        error('Magic invalid, this is not an PTU file.');
    end
    Version = fread(fid, 8, '*char');
%     fprintf(1,'Tag Version: %s\n', Version);

    % there is no repeat.. until (or do..while) construct in matlab so we use
    % while 1 ... if (expr) break; end; end;
    while 1
        % read Tag Head
        TagIdent = fread(fid, 32, '*char'); % TagHead.Ident
        TagIdent = (TagIdent(TagIdent ~= 0))'; % remove #0 and more more readable
        TagIdx = fread(fid, 1, 'int32');    % TagHead.Idx
        TagTyp = fread(fid, 1, 'uint32');   % TagHead.Typ
                                            % TagHead.Value will be read in the
                                            % right type function
        if TagIdx > -1
          EvalName = [TagIdent '(' int2str(TagIdx + 1) ')'];
        else
          EvalName = TagIdent;
        end
%         fprintf(1,'\n   %-40s', EvalName);
        % check Typ of Header
        switch TagTyp
            case tyEmpty8
                fread(fid, 1, 'int64');
%                 fprintf(1,'<Empty>');
            case tyBool8
                TagInt = fread(fid, 1, 'int64');
                if TagInt==0
%                     fprintf(1,'FALSE');
                    eval([EvalName '=false;']);
                else
%                     fprintf(1,'TRUE');
                    eval([EvalName '=true;']);
                end
            case tyInt8
                TagInt = fread(fid, 1, 'int64');
%                 fprintf(1,'%d', TagInt);
                eval([EvalName '=TagInt;']);
            case tyBitSet64
                TagInt = fread(fid, 1, 'int64');
%                 fprintf(1,'%X', TagInt);
                eval([EvalName '=TagInt;']);
            case tyColor8
                TagInt = fread(fid, 1, 'int64');
%                 fprintf(1,'%X', TagInt);
                eval([EvalName '=TagInt;']);
            case tyFloat8
                TagFloat = fread(fid, 1, 'double');
%                 fprintf(1, '%e', TagFloat);
                eval([EvalName '=TagFloat;']);
            case tyFloat8Array
                TagInt = fread(fid, 1, 'int64');
%                 fprintf(1,'<Float array with %d Entries>', TagInt / 8);
                fseek(fid, TagInt, 'cof');
            case tyTDateTime
                TagFloat = fread(fid, 1, 'double');
%                 fprintf(1, '%s', datestr(datenum(1899,12,30)+TagFloat)); % display as Matlab Date String
                eval([EvalName '=datenum(1899,12,30)+TagFloat;']); % but keep in memory as Matlab Date Number
            case tyAnsiString
                TagInt = fread(fid, 1, 'int64');
                TagString = fread(fid, TagInt, '*char');
                TagString = (TagString(TagString ~= 0))';
%                 fprintf(1, '%s', TagString);
                if TagIdx > -1
                   EvalName = [TagIdent '{' int2str(TagIdx + 1) '}'];
                end
                eval([EvalName '=[TagString];']);
            case tyWideString
                % Matlab does not support Widestrings at all, just read and
                % remove the 0's (up to current (2012))
                TagInt = fread(fid, 1, 'int64');
                TagString = fread(fid, TagInt, '*char');
                TagString = (TagString(TagString ~= 0))';
%                 fprintf(1, '%s', TagString);
                if TagIdx > -1
                   EvalName = [TagIdent '{' int2str(TagIdx + 1) '}'];
                end
                eval([EvalName '=[TagString];']);
            case tyBinaryBlob
                TagInt = fread(fid, 1, 'int64');
%                 fprintf(1,'<Binary Blob with %d Bytes>', TagInt);
                fseek(fid, TagInt, 'cof');
            otherwise
                error('Illegal Type identifier found! Broken file?');
        end
        if strcmp(TagIdent, 'Header_End')
            break
        end
    end
    fprintf(1, '\n----------------------------------------------------\n');
%% ========================================================================
    % Check recordtype
    global isT2;
    switch TTResultFormat_TTTRRecType
        case rtTimeHarp260PT2
            isT2 = true;
            fprintf(1,'TimeHarp260P T2 data\n');
        otherwise
            error('Illegal RecordType!');
    end
    fprintf(1,'\nThis may take a while...');
    % choose right decode function
    switch TTResultFormat_TTTRRecType
        case rtTimeHarp260PT2
            isT2 = true;
            [Raw_stamps, time_stamps, ch, n_ovfl] = ReadHT2;
        otherwise
            error('Illegal RecordType!');
    end
    fclose(fid);
    fprintf(1,'\n');
    fprintf(1,'Finished!  \n\n');
    fprintf(1,'\n');
    
    %% ============================= writing the results:
    if save_csv~=0
        outfile_ch = [pathname filename(1:length(filename)-4) '_ch.csv'];
        outfile_T = [pathname filename(1:length(filename)-4) '_T.csv'];
        csvwrite(outfile_ch,ch);
        csvwrite(outfile_T,time_stamps);
    end
end

%% Read HydraHarp/TimeHarp260 T2
function [Raw_stamps, time_stamps, ch, n_ovfl] = ReadHT2
        time_stamps=[]; ch=[];
        Raw_stamps=[];
    global fid;
    global TTResult_NumberOfRecords; % Number of TTTR Records in the File;
    
    n_ovfl=0;
    OverflowCorrection = 0;
    T2WRAPAROUND= 2^25; %  25 bit of time stamping!

    for i=1:TTResult_NumberOfRecords
        T2Record = fread(fid, 1, 'ubit32');     % all 32 bits:
        Raw_stamps=[Raw_stamps;T2Record];
        %   +-------------------------------+  +-------------------------------+
        %   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        %   +-------------------------------+  +-------------------------------+
        dtime = bitand(T2Record,T2WRAPAROUND-1);   % the last 25 bits:
        %   +-------------------------------+  +-------------------------------+
        %   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        %   +-------------------------------+  +-------------------------------+
        channel = bitand(bitshift(T2Record,-25),63);   % the next 6 bits:
        %   +-------------------------------+  +-------------------------------+
        %   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
        %   +-------------------------------+  +-------------------------------+
        special = bitand(bitshift(T2Record,-31),1);   % the last bit:
        %   +-------------------------------+  +-------------------------------+
        %   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
        %   +-------------------------------+  +-------------------------------+
        % the resolution in T2 mode is 1 ps  - IMPORTANT! THIS IS NEW IN FORMAT V2.0
        if channel == 63  % overflow of dtime occured
            n_ovfl=n_ovfl+1;
            if(dtime == 0)  % if dtime is zero it is an old style single overflow
                OverflowCorrection = OverflowCorrection + T2WRAPAROUND;
            else            % otherwise dtime indicates the number of overflows - THIS IS NEW IN FORMAT V2.0
                OverflowCorrection = OverflowCorrection + T2WRAPAROUND * dtime;
            end
        else
            if special ==0
                channel=channel+1;
            end
            timetag = OverflowCorrection + dtime;
            time_stamps=[time_stamps; timetag];
            ch=[ch;channel];
        end
    end
end
