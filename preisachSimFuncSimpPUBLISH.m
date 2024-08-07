function preisachSimFuncSimpPUBLISH(block) ;  setup(block);
  
function setup(block)
  
  block.NumDialogPrms  = 4;
  %%% Parameters structure is ordered as follows     {   [Mi ; Pi] A u0 e    }
  
  %% Register number of input and output ports
  block.NumInputPorts  = 1;
  block.NumOutputPorts = 1;

  %% Setup functional port properties to dynamically
  %% inherited.
  block.SetPreCompInpPortInfoToDynamic;
  block.SetPreCompOutPortInfoToDynamic;
 
  block.InputPort(1).Dimensions        = 1;
  block.InputPort(1).DirectFeedthrough = true;
  
  block.OutputPort(1).Dimensions       = 1;
  
  %% Set block sample time to inherited
  block.SampleTimes = [0 0];
  
  %% Register methods
  block.RegBlockMethod('PostPropagationSetup',    @DoPostPropSetup);
  block.RegBlockMethod('InitializeConditions',    @InitConditions);  
  block.RegBlockMethod('Outputs',                 @Output);  
%   block.RegBlockMethod('Update',                  @Update);  

function DoPostPropSetup(block)

  %% Setup Dwork
  block.NumDworks = 4;
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Setting input storage and dominant %%%%
  %%% extrema storage buffers %%%%%%%%%%%%%%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  block.Dwork(1).Name = 'uSeg'; 
  block.Dwork(1).Dimensions      = 10000;
  block.Dwork(1).DatatypeID      = 0;
  block.Dwork(1).Complexity      = 'Real';
  block.Dwork(1).UsedAsDiscState = true;
  
  block.Dwork(2).Name = 'MkBuffer'; 
  block.Dwork(2).Dimensions      = 500;
  block.Dwork(2).DatatypeID      = 0;
  block.Dwork(2).Complexity      = 'Real';
  block.Dwork(2).UsedAsDiscState = true;
  
  block.Dwork(3).Name = 'mkBuffer'; 
  block.Dwork(3).Dimensions      = 500;
  block.Dwork(3).DatatypeID      = 0;
  block.Dwork(3).Complexity      = 'Real';
  block.Dwork(3).UsedAsDiscState = true;

  block.Dwork(4).Name = 'slopeFlag'; 
  block.Dwork(4).Dimensions      = 1;
  block.Dwork(4).DatatypeID      = 0;
  block.Dwork(4).Complexity      = 'Real';
  block.Dwork(4).UsedAsDiscState = true;
  


function InitConditions(block)

  %% Initialize Dwork
    
  % Input storage buffer for min max scans of input segments
  block.Dwork(1).Data = NaN(1,block.Dwork(1).Dimensions);
  block.Dwork(1).Data(1) = -inf;
  
  %%%%% Defining Initial Magnetic History %%%%%%%%
  block.Dwork(2).Data = NaN(1,block.Dwork(2).Dimensions);
  block.Dwork(2).Data(1:400) = [4:-0.01:0.01];    

  block.Dwork(3).Data = NaN(1,block.Dwork(3).Dimensions);
  block.Dwork(3).Data(1) = -inf;  
  block.Dwork(3).Data(2:401) = [-4:0.01:-0.01];   
  
  
  % Assumed initial slope direction (+1 = increasing)
  block.Dwork(4).Data = 1;  
%   


function Output(block)

% init = block.Dwork(8).Data;

% Extract user input parameters
x.Mi = block.DialogPrm(1).Data(:,1);
x.Pi = block.DialogPrm(1).Data(:,2);
x.A = block.DialogPrm(2).Data;
x.u0 = block.DialogPrm(3).Data;
x.e = block.DialogPrm(4).Data;

% Retrieve present input and Preisach memory from storage buffers
uSeg   = block.Dwork(1).Data.';
MkBuff = block.Dwork(2).Data.';
mkBuff = block.Dwork(3).Data.';

s = block.Dwork(4).Data;  % Get initial slope flag ( only used once )

u = block.InputPort(1).Data;  % Get current input value

            lenUseg = find(~isnan(uSeg),1,'last');
            
            uSeg(lenUseg+1) = u;
            lenUseg = lenUseg +1 ;
          
            % Else slope is negative (i.e., input is decreasing)
                if u>uSeg(lenUseg-1)
                    s = 1;  %%% set flag
                else %%% 
                     s = 0;    %%% reset flag
                end
      
        [~,maxIndx] = nanmax(uSeg);
        [~,minIndx] = nanmin(uSeg);      
       
        % if passed a minimum turning point and ascending
        if  minIndx<lenUseg && s==1 
            
            len = length(uSeg(minIndx:end));
            uSeg(1:len) = uSeg(minIndx:end);            
            uSeg(len+1:end) = NaN;
       
            indx = MkBuff>u;          % Find index for all Mk set still above current input
            
            lastMkIndx = sum(indx);   % Get new index of last Mk value (just before NaNs)
            
            MkBuff(1:lastMkIndx) = MkBuff(indx);         
            MkBuff(lastMkIndx+1) = u;  % Store current input to the end of the Mk buffer set of maxima  
            lastMkIndx = lastMkIndx + 1;
            
            MkBuff(lastMkIndx+1:end) = NaN;   % Assure NaNs are placed after last number to end of buffer 
            mkBuff(lastMkIndx+1:end) = NaN;   % wipe out dominant minima that occured between the two maxima
            mkBuff(lastMkIndx+1) = u;       % The special case: for increasing input, the last mk value should be the current input value.
            lastmkIndx = lastMkIndx+1;  % Since we have wiped out some mk values, we must also update the index of the last mk value (just before NaNs) in the mk buffer .
            
       end
        
        if maxIndx<lenUseg && s==0 % if passed a max turning point and descending
            
            len = length(uSeg(maxIndx:end));
            uSeg(1:len) = uSeg(maxIndx:end);
            uSeg(len+1:end) = NaN;


            indx = mkBuff<u;   % Find index for all mk set still below current input
            
            lastmkIndx = sum(indx);   % Get new index of last mk value (just before NaNs)
            
            mkBuff(1:lastmkIndx) = mkBuff(indx);     % Keep only values not wiped out by input
            mkBuff(lastmkIndx+1) = u;    % Store current input to the end of mk set of minima
            lastmkIndx = lastmkIndx + 1;
            
            mkBuff(lastmkIndx+1:end) = NaN;   % Assure NaNs are placed after last number to end of buffer 
            MkBuff(lastmkIndx:end) = NaN;   % wipe out dominant maxima that occured between the two maxima
            
            lastMkIndx = lastmkIndx-1;  % Since we have wiped out some Mk values, we must also update the index of the last Mk value (just before NaNs) in the Mk buffer .
            
          
        end  
   
                sumF = sum(Fab(MkBuff(1:lastMkIndx),mkBuff(1:lastmkIndx-1),x) ... 
                          -Fab(MkBuff(1:lastMkIndx),mkBuff(2:lastmkIndx),x),2);
                
  
                B = -Fab(inf,-inf,x) + 2.*sumF + 0.05*sign(u)*log(2000*abs(u)+1);

        
        % Update memory buffers
        block.Dwork(1).Data = uSeg.';   % Update input memory segment
        block.Dwork(2).Data = MkBuff.'; % Update dominant maxima vector
        block.Dwork(3).Data = mkBuff.'; % Update dominant minima vector


        % Send calculated output to block's output port
        block.OutputPort(1).Data = B;  

