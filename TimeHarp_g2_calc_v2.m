%% TimeHarp timestamps analysis:
%  cross-correlation between sync & ch1
%% =============================================
tic

%% ====================== Some parameters:
    tb=0.025;   %[ns]

    prompt = {'BinWidth [ns]:','Range [ns]:'};
    dlgtitle = 'Histogram parameters';
    dims = [1 35];
    definput = {'0.5','100'};
    answer = inputdlg(prompt,dlgtitle,dims,definput);
    hist_range=str2num(answer{2});
    binW=str2num(answer{1});
    BinLim = [-hist_range hist_range];
    BinEdge = -hist_range:binW:hist_range;

    %% ====================== Conversion (ptu to out)?:
    conversion = questdlg('Need conversion (ptu to out)?', ...
        '', 'Yes','No','Yes');
    switch conversion
        case 'Yes'
            [~,T,ch,~, fname]=Read_PTU_v4(0);
        case 'No'
            [ch_filename]=uigetfile({'*.csv';'*.txt'}, 'Select Channel data file:');
            [T_filename]=uigetfile({'*.csv';'*.txt'}, 'Select Timestamps data file:');
            T=csvread(T_filename);
            ch=csvread(ch_filename);
    end
    N_split=100000;
    N_T=length(T);
    %% ====================== Compute Coincidences:
    dt_cell={};
    if N_T > N_split
        Tot_det1=0; Tot_det2=0;
        for i=1:floor(N_T/N_split)
            fprintf('\t =======\tstep %i out of %i \n', i, floor(N_T/N_split)+1)
            T_split = T ((i-1)*N_split+1:i*N_split);
            ch_split= ch((i-1)*N_split+1:i*N_split);
            t2=T_split(ch_split==1);
            t1=T_split(ch_split==0);
            dt=[];
            if numel(t2)<numel(t1)
                for j=1:numel(t2)
                    dt12=tb*(t1-t2(j));
                    dt=[dt; dt12(abs(dt12)<hist_range)];
                end
            else
                for j=1:numel(t1)
                    dt12=tb*(t1(j)-t2);
                    dt=[dt; dt12(abs(dt12)<hist_range)];
                end
            end
            dt_cell{i}=dt;
            Tot_det1 = Tot_det1+length(t1);
            Tot_det2 = Tot_det2+length(t2);
        end
        fprintf('\t =======\tstep %i out of %i \n', i+1, floor(N_T/N_split)+1)
        T_split = T (i*N_split+1:end);
        ch_split= ch(i*N_split+1:end);
        t2=T_split(ch_split==1);
        t1=T_split(ch_split==0);
        if numel(t2)<numel(t1)
            for j=1:numel(t2)
                dt12=tb*(t1-t2(j));
                dt=[dt; dt12(abs(dt12)<hist_range)];
            end
        else
            for j=1:numel(t1)
                dt12=tb*(t1(j)-t2);
                dt=[dt; dt12(abs(dt12)<hist_range)];
            end
        end
        Tot_det1 = Tot_det1+length(t1);
        Tot_det2 = Tot_det2+length(t2);
    else
        fprintf('\n\t Small TimeStamps Array Size.\n');
        t2=T(ch==1);
        t1=T(ch==0);
        dt=[];
        if numel(t2)<numel(t1)
            for i=1:numel(t2)
                dt12=tb*(t1-t2(i));
                dt=[dt; dt12(abs(dt12)<hist_range)];
            end
        else
            for i=1:numel(t1)
                dt12=tb*(t1(i)-t2);
                dt=[dt; dt12(abs(dt12)<hist_range)];
            end
        end
        dt_cell{1}=dt;
        Tot_det1 = length(t1);
        Tot_det2 = length(t2);
    end
    t_acquis = (T(end)-T(1))*tb*1E-9;
    norm=Tot_det1*Tot_det2*(binW*1E-9)/t_acquis;

    %% ====================== Plotting:
    for i=1:length(dt_cell)
        G2_arr(i,:) = histcounts(dt_cell{i}, BinEdge);
    end
    G2 = sum(G2_arr);
    tau = BinEdge(1:end-1)+binW/2;
    g2_norm = G2/norm;
    g2_err = 1./(sqrt(G2)*norm);    % assuming Poissonian statistics!

    figure('Name','Normalized g2','NumberTitle','off'); 
    h=errorbar(tau,g2_norm,g2_err,'o');
    Plot_formatting(h,'\tau [ns]', 'Normalized g^{(2)}(\tau)')
    h2=gca;
    h2.XLim=[-hist_range, hist_range];
    h2.YLim=[0,1.5];

    %% ====================== Display results:
    g2_0 = mean(g2_norm(abs(tau) < binW));
    g2_0_err = mean(g2_err(abs(tau) < binW));
        fprintf('\n===================================================\n')
        fprintf('\n\t TOTAL DETECTION 1 : %d counts \n' , Tot_det1)
        fprintf('\t TOTAL DETECTION 2 : %d counts \n' , Tot_det2)
        fprintf('\t TOTAL ACQUISITION TIME : %2.2f [s] \n' , t_acquis)
        fprintf('\t COUNT RATE 1 : %6.2f [cps] \n' , Tot_det1 / t_acquis)
        fprintf('\t COUNT RATE 2 : %6.2f [cps] \n\n' , Tot_det2 / t_acquis)
        fprintf('\t\t g2(0) = %1.4f +/- %1.4f \n' , g2_0, g2_0_err)
        fprintf('\n===================================================\n')
        
    %% ====================== Save figure:
    save_fig = questdlg('Save figure?','','Yes','No','Yes');
    switch save_fig
        case 'Yes'
            savefig([fname(1:end-4) '.fig']);
    end

toc