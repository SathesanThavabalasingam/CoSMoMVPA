function [winners,classes]=comso_winner_indices(pred)
% Get indices of sample values that occur most often
%
% [winners,classes]=comso_winner_indices(pred)
%
% Input:
%   pred              PxQ prediction values for Q features. Values <= 0
%                     are ignored, i.e. can never be a winner
%
% Output:
%   winners           1xQ indices of classes that occur most often.
%                     winners(k)==w means that no value in pred(:,k) 
%                     occurs more often than classes(w)
%   classes           The sorted list of unique predicted values.
%
% Example:
% .. cosmo_winner_indices([1 1 1; 1 2 3; 1 2 2; 3 0 0]')
% > [ 1 3 2 3]
%
% Note: the current implementaiton selects a winner pseudo-randomly in
% case of a tie between multiple winners. In this implementation,
% repeatedly calling this function with identical input yields identical
% output.
%
% NNO Aug 2013

[nsamples,nfeatures]=size(pred);
msk=pred>0; % ignore those without predictions

mx_pred=max(pred(:));

counts=histc(pred',1:mx_pred)';
% optimization: if all classes in range 1:mx_pred then set classes directly
if sum(counts(:))==sum(msk(:)) && all(sum(counts)>0)
    classes=(1:mx_pred)';
else
    classes=unique(pred(msk)); % see which classes are predicted (slower)
    counts=histc(pred',classes)'; % how often each class was predicted
end

[mx,mxi]=max(counts,[],2); % the first class in each feature that was predicted most often

winners_msk=bsxfun(@eq,counts,mx); % mask with classes that are the winners
nwinners=sum(winners_msk,2); % for each feature the number of winners

winners=zeros(nsamples,1); % allocate space for output

% little optimization: first take features with just one winner
one_winner=nwinners==1;
winners(one_winner)=mxi(one_winner);

% now consider the remaning ones - with multiple winners
multiple_winners=~one_winner;
winners_msk=bsxfun(@and,winners_msk,multiple_winners);
        
seed=sum(winners_msk(:)); % get some semi-random number to start with

% get the rows (which correspond to indices of class winners) and columns
% (corresponding to each feature)
[wrows,wcols]=ind2sub(size(winners_msk),find(winners_msk));

colpos=0; % referring to wcols
for k=find(multiple_winners)' % treat each feature seperately
    nwinner=nwinners(k);
    seed=seed+nwinner; % pseudorandomly update the seed
    wind=colpos+(1:nwinner); % indices of winner values
    
    idx=mod(seed, nwinner)+1; % select one value randomly in range 1..nwinner
    winners(k)=wcols(wind(idx)); % set the winner accordingly
    
    colpos=colpos+nwinner; % update for next iteration
end

%classes=classes';