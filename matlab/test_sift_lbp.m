
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  ICPR 2014 Tutorial                                                     %
%  Hands on Advanced Bag-of-Words Models for Visual Recognition           %
%                                                                         %
%  Instructors:                                                           %
%  L. Ballan     <lamberto.ballan@unifi.it>                               %
%  L. Seidenari  <lorenzo.seidenari@unifi.it>                             %

%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%                                                                         %
%   BOW pipeline: Image classification using bag-of-features              %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%   Part 1:  Load and quantize pre-computed image features                %
%   Part 2:  Represent images by histograms of quantized features         %
%   Part 3:  Classify images with nearest neighbor classifier             %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% (OBL)
clear;
close all;
clc;
% DATASET
%dataset_dir='garbage_classification'; %dataset_folder_name
dataset_dir = 'ds2';
%dataset_dir = 'prova_resized_bn_2';

% FEATURES extraction methods
% 'sift' for sparse features detection (SIFT descriptors computed at  
% Harris-Laplace keypoints) or 'dsift' for dense features detection (SIFT
% descriptors computed at a grid of overlapped patches

%desc_name = 'sift';
%desc_name = 'dsift';
desc_name = 'msdsift';
%desc_name = 'color_sift';

% FLAGS
do_feat_extraction = 1;
do_split_sets = 1;
do_form_codebook = 1;
do_feat_quantization = 1;
do_show_logs = 1;

do_visualize_feat = 0;
do_visualize_words = 0;
do_visualize_confmat = 0;
do_visualize_res = 0;
do_have_screen = 0; %~isempty(getenv('DISPLAY'));

do_L2_NN_classification = 0;
do_chi2_NN_classification = 0;

do_svm_linar_classification = 0;
do_svm_llc_linar_classification = 0;
do_svm_precomp_linear_classification = 0;
do_svm_inter_classification = 0;
do_svm_chi2_classification = 1;

visualize_feat = 0;
visualize_words = 0;
visualize_confmat = 0;
visualize_res = 0;
%have_screen = ~isempty(getenv('DISPLAY'));
have_screen = 0;
% PATHS
basepath = '..';
wdir = pwd;
libsvmpath = [ wdir(1:end-6) fullfile('lib','libsvm-3.11','matlab')];
addpath(libsvmpath)

% BOW PARAMETERS
max_km_iters = 1500; % maximum number of iterations for k-means
nfeat_codebook = 500000; % number of descriptors used by k-means for the codebook generation
norm_bof_hist = 1;

% number of images selected for training (e.g. 30 for Caltech-101)
num_train_img = 142; %numero per ogni classe
% number of images selected for test (e.g. 50 for Caltech-101)
num_test_img = 46;  %numero per ogni classe
%number of images selected for validation
num_val_img = 46;
% number of codewords (i.e. K for the k-means algorithm)
nwords_codebook = 1200;
%NUmero massimo di immagini prendibili per ogni classe
num_max_img_per_classe = 238;

% image file extension
file_ext='jpg';

%% Create a new dataset split
file_split = 'split.mat';
if do_split_sets    
    data = create_dataset_split_structure_from_unbalanced_sets_val(...
        fullfile(basepath, 'img', dataset_dir), ... 
        num_train_img, ...
        num_val_img, ...
        num_test_img , ...
        file_ext, ...
        num_max_img_per_classe); %numero di immagini massimo da considerare per classe
    save(fullfile(basepath,'img',dataset_dir,file_split),'data');
else
    load(fullfile(basepath,'img',dataset_dir,file_split));
end
classes = {data.classname}; % create cell array of class name strings

disp("Immagini caricate correttamente")

% Extract SIFT features fon training and test images
if do_feat_extraction   
    extract_sift_features(fullfile('..','img',dataset_dir),desc_name)    
end

disp("Estrazione delle feature SIFT completata correttamente")

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Part 1: quantize pre-computed image features %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 
%%Compute  LBP for each image

%definition about path information
info.base = basepath;
info.first = "img";
info.dsdir = dataset_dir;
info.desc_name = desc_name;
[trainLBP,valLBP, testLBP] = lbp_val_extraction(data,length(classes),num_train_img, num_val_img, num_test_img, info);
for i = 1 : size(trainLBP,2)
    trainLBP(i).hist = double(trainLBP(i).hist);
end

for i = 1 : size(testLBP,2)
    testLBP(i).hist = double(testLBP(i).hist);
end

for i = 1 : size(valLBP,2)
    valLBP(i).hist = double(valLBP(i).hist);
end


%% Load pre-computed SIFT features for training images (OBL)

% The resulting structure array 'desc' will contain one
% entry per images with the following fields:
%  desc(i).r :    Nx1 array with y-coordinates for N SIFT features
%  desc(i).c :    Nx1 array with x-coordinates for N SIFT features
%  desc(i).rad :  Nx1 array with radius for N SIFT features
%  desc(i).sift : Nx128 array with N SIFT descriptors
%  desc(i).imgfname : file name of original image

lasti=1;
for i = 1:length(data) %per ogni categoria trovata
     images_descs = get_descriptors_files_val(data,i,file_ext,desc_name,'train'); %ex. 0001.dsift
     for j = 1:length(images_descs) 
        fname = fullfile(basepath,'img',dataset_dir,data(i).classname,images_descs{j});
        if do_show_logs
            fprintf('Loading %s \n',fname);
        end
        tmp = load(fname,'-mat');
        tmp.desc.class=i;
        tmp.desc.imgfname=regexprep(fname,['.' desc_name],'.jpg');
        desc_train(lasti)=tmp.desc;
        desc_train(lasti).sift = single(desc_train(lasti).sift);
        lasti=lasti+1;
    end;
end;
%% Visualize SIFT features for training images
if 0 %(do_visualize_feat && do_have_screen)
    nti=2;
    fprintf('\nVisualize features for %d training images\n', nti);
    imgind=randperm(length(desc_train));
    for i=1:nti
        d=desc_train(imgind(i));
        clf, showimage(imread(strrep(d.imgfname,'_train','')));
        x=d.c;
        y=d.r;
        rad=d.rad;
        showcirclefeaturesrad([x,y,rad]);
        %title(sprintf('%d features in %s',length(d.c),d.imgfname));
        pause
    end
end


%% Load pre-computed SIFT features for test images (OBL)

lasti=1;
for i = 1:length(data)
     images_descs = get_descriptors_files_val(data,i,file_ext,desc_name,'test');
     for j = 1:length(images_descs) 
        fname = fullfile(basepath,'img',dataset_dir,data(i).classname,images_descs{j});
        fprintf('Loading %s \n',fname);
        tmp = load(fname,'-mat');
        tmp.desc.class=i;
        tmp.desc.imgfname=regexprep(fname,['.' desc_name],'.jpg');
        desc_test(lasti)=tmp.desc;
        desc_test(lasti).sift = single(desc_test(lasti).sift);
        lasti=lasti+1;
    end;
end;

%% Load pre-computed SIFT features for validation images (OBL)

lasti=1;
for i = 1:length(data)
     images_descs = get_descriptors_files_val(data,i,file_ext,desc_name,'val');
     for j = 1:length(images_descs) 
        fname = fullfile(basepath,'img',dataset_dir,data(i).classname,images_descs{j});
        fprintf('Loading %s \n',fname);
        tmp = load(fname,'-mat');
        tmp.desc.class=i;
        tmp.desc.imgfname=regexprep(fname,['.' desc_name],'.jpg');
        desc_val(lasti)=tmp.desc;
        desc_val(lasti).sift = single(desc_val(lasti).sift);
        lasti=lasti+1;
    end;
end;


%% Build visual vocabulary using k-means (OBL) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if do_form_codebook
    fprintf('\nBuild visual vocabulary:\n');

    % concatenate all descriptors from all images into a n x d matrix 
    DESC = [];
    labels_train = cat(1,desc_train.class);
    for i=1:length(data) %per ogni categoria delle immagini da classificare
        desc_class = desc_train(labels_train==i);
        randimages = randperm(num_train_img);
        randimages = randimages(1:5); %perché prende solo le prime 5?
        DESC = vertcat(DESC,desc_class(randimages).sift);
        %a caso vengono prese le sift di 
    end
%% 

    % sample random M (e.g. M=20,000) descriptors from all training descriptors
    r = randperm(size(DESC,1));

    %% 

    r = r(1:min(length(r),nfeat_codebook));

    DESC = DESC(r,:);
    %% 
    
    % run k-means
    K = nwords_codebook; % size of visual vocabulary
    fprintf('running k-means clustering of %d points into %d clusters...\n',...
        size(DESC,1),K)
    % input matrix needs to be transposed as the k-means function expects 
    % one point per column rather than per row

    % form options structure for clustering
    cluster_options.maxiters = max_km_iters;
    cluster_options.verbose  = 2;

    [VC] = kmeans_bo(double(DESC),K,max_km_iters);%visual codebook
    VC = VC';%transpose for compatibility with following functions
    %clear DESC;
end



%% (OBL) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%   EXERCISE 1: K-means Descriptor quantization                           %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% K-means descriptor quantization means assignment of each feature
% descriptor with the identity of its nearest cluster mean, i.e.
% visual word. Your task is to quantize SIFT descriptors in all
% training and test images using the visual dictionary 'VC'
% constructed above.
%
% TODO:
% 1.1 compute Euclidean distances between VC and all descriptors
%     in each training and test image. Hint: to compute all-to-all
%     distance matrix for two sets of descriptors D1 & D2 use
%     dmat=eucliddist(D1,D2);
% 1.2 compute visual word ID for each feature by minimizing
%     the distance between feature SIFT descriptors and VC.
%     Hint: apply 'min' function to 'dmat' computed above along
%     the dimension (1 or 2) corresponding to VC, i.g.:
%     [mv,visword]=min(dmat,[],2); if you compute dmat as 
%     dmat=eucliddist(dscr(i).sift,VC);

if do_feat_quantization
    fprintf('\nFeature quantization (hard-assignment)...\n');
    %quantizzazione per le immagini di train
    for i=1:length(desc_train)  
      sift = desc_train(i).sift(:,:);
      dmat = eucliddist(sift,VC); %distanza euclidea in 128-dimensioni
      %dmat mi dice la distanza del des crittore del keypoint da ogni
      %keyword.
      [quantdist,visword] = min(dmat,[],2); %prendo keyword + vicina
      % save feature labels
      desc_train(i).visword = visword;
      desc_train(i).quantdist = quantdist;
    end

    for i=1:length(desc_test)    
      sift = desc_test(i).sift(:,:); 
      dmat = eucliddist(sift,VC);
      [quantdist,visword] = min(dmat,[],2);
      % save feature labels
      desc_test(i).visword = visword;
      desc_test(i).quantdist = quantdist;
    end

    for i=1:length(desc_val)    
      sift = desc_val(i).sift(:,:); 
      dmat = eucliddist(sift,VC);
      [quantdist,visword] = min(dmat,[],2);
      % save feature labels
      desc_val(i).visword = visword;
      desc_val(i).quantdist = quantdist;
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 1                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Visualize visual words (i.e. clusters) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  To visually verify feature quantization computed above, we can show 
%  image patches corresponding to the same visual word. 

if 0 %(do_visualize_words && do_have_screen)
    figure;
    %num_words = size(VC,1) % loop over all visual word types
    num_words = 5;
    fprintf('\nVisualize visual words (%d examples)\n', num_words);
    for i=1:num_words
      patches={};
      for j=1:length(desc_train) % loop over all images
        d=desc_train(j);
        ind=find(d.visword==i);
        if length(ind)
          %img=imread(strrep(d.imgfname,'_train',''));
          img=rgb2gray(imread(d.imgfname));
          
          x=d.c(ind); y=d.r(ind); r=d.rad(ind);
          bbox=[x-2*r y-2*r x+2*r y+2*r];
          for k=1:length(ind) % collect patches of a visual word i in image j      
            patches{end+1}=cropbbox(img,bbox(k,:));
          end
        end
      end
      % display all patches of the visual word i
      clf, showimage(combimage(patches,[],1.5))
      title(sprintf('%d examples of Visual Word #%d',length(patches),i))
      pause
    end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Part 2: represent images with BOF histograms %%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%   EXERCISE 2: Bag-of-Features image classification                      %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Represent each image by the normalized histogram of visual (OBL)
% word labels of its features. Compute word histogram H over 
% the whole image, normalize histograms w.r.t. L1-norm.
%
% TODO:
% 2.1 for each training and test image compute H. Hint: use
%     Matlab function 'histc' to compute histograms.


N = size(VC,1); % number of visual words

for i=1:length(desc_train) 
    visword = desc_train(i).visword; 
    %visword = visualword associata ad ogni keypoint dell'img

    H = histc(visword,[1:nwords_codebook]);
  
    % normalize bow-hist (L1 norm)
    if norm_bof_hist
        H = H/sum(H);
    end
  
    % save histograms
    desc_train(i).bof=H(:)';
end

for i=1:length(desc_test) 
    visword = desc_test(i).visword;
    H = histc(visword,[1:nwords_codebook]);
  
    % normalize bow-hist (L1 norm)
    if norm_bof_hist
        H = H/sum(H);
    end
  
    % save histograms
    desc_test(i).bof=H(:)';
end


for i=1:length(desc_val) 
    visword = desc_val(i).visword;
    H = histc(visword,[1:nwords_codebook]);
  
    % normalize bow-hist (L1 norm)
    if norm_bof_hist
        H = H/sum(H);
    end
  
    % save histograms
    desc_val(i).bof=H(:)';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 2                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp("Sezione 2 Eseguita")
%%

%%%%LLC Coding
if do_svm_llc_linar_classification
    for i=1:length(desc_train)
        disp(desc_train(i).imgfname);
        desc_train(i).llc = max(LLC_coding_appr(VC,desc_train(i).sift)); %max-pooling
        desc_train(i).llc=desc_train(i).llc/norm(desc_train(i).llc); %L2 normalization
    end
    for i=1:length(desc_test) 
        disp(desc_test(i).imgfname);
        desc_test(i).llc = max(LLC_coding_appr(VC,desc_test(i).sift));
        desc_test(i).llc=desc_test(i).llc/norm(desc_test(i).llc);
    end
    for i=1:length(desc_val) 
        disp(desc_val(i).imgfname);
        desc_val(i).llc = max(LLC_coding_appr(VC,desc_val(i).sift));
        desc_val(i).llc=desc_val(i).llc/norm(desc_val(i).llc);
    end
end
%%%%end LLC coding

%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Part 3: image classification %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Concatenate bof-histograms into training and test matrices 
bof_train=cat(1,desc_train.bof);
bof_test=cat(1,desc_test.bof);
bof_val = cat(1,desc_val.bof);
f_train=cat(1,trainLBP.hist);
f_test=cat(1,testLBP.hist);
f_val = cat(1, valLBP.hist);
if do_svm_llc_linar_classification
    llc_train = cat(1,desc_train.llc);
    llc_test = cat(1,desc_test.llc);
    llc_val = cat(1, desc_test.llc);
end


% Construct label Concatenate bof-histograms into training and test matrices 
labels_train=cat(1,desc_train.class);
labels_test=cat(1,desc_test.class);
labels_val=cat(1,desc_val.class);

new_bof_train = [bof_train,f_train];
new_bof_test = [bof_test,f_test];
new_bof_val = [bof_val,f_val];


%% NN classification %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if do_L2_NN_classification
    % Compute L2 distance between BOFs of test and training images
    bof_l2dist=eucliddist(bof_test,bof_train);
    
    % Nearest neighbor classification (1-NN) using L2 distance
    [mv,mi] = min(bof_l2dist,[],2); %val, colonna nel train
    bof_l2lab = labels_train(mi);
    
    method_name='NN L2';
    acc=sum(bof_l2lab==labels_test)/length(labels_test);
    fprintf('\n*** %s ***\nAccuracy = %1.4f%% (classification)\n',method_name,acc*100);
   
    % Compute classification accuracy
    compute_accuracy(data,labels_test, ...
        bof_l2lab,classes, ...
        method_name,desc_test,...
        do_visualize_confmat & do_have_screen,... 
        do_visualize_res & do_have_screen);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%   EXERCISE 3: Image classification                                      %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                                           
%% Repeat Nearest Neighbor image classification using Chi2 distance
% instead of L2. Hint: Chi2 distance between two row-vectors A,B can  
% be computed with d=chi2(A,B);
%
% TODO:
% 3.1 Nearest Neighbor classification with Chi2 distance
%     Compute and compare overall and per-class classification
%     accuracies to the L2 classification above


if do_chi2_NN_classification
    % compute pair-wise CHI2
    bof_chi2dist = zeros(size(bof_test,1),size(bof_train,1));
    
    % bof_chi2dist = slmetric_pw(bof_train, bof_test, 'chisq');
    for i = 1:size(bof_test,1)
        for j = 1:size(bof_train,1)
            bof_chi2dist(i,j) = chi2(bof_test(i,:),bof_train(j,:)); 
        end
    end

    % Nearest neighbor classification (1-NN) using Chi2 distance
    [mv,mi] = min(bof_chi2dist,[],2);
    bof_chi2lab = labels_train(mi);

    method_name='NN Chi-2';
    acc=sum(bof_chi2lab==labels_test)/length(labels_test);
    fprintf('*** %s ***\nAccuracy = %1.4f%% (classification)\n',method_name,acc*100);
 
    % Compute classification accuracy
    compute_accuracy(data,labels_test,bof_chi2lab,classes,method_name,desc_test,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 3.1                                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% SVM classification (using libsvm) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Use cross-validation to tune parameters:
% - the -v 5 options performs 5-fold cross-validation, this is useful to tune 
% parameters
% - the result of the 5 fold train/test split is averaged and reported
%
% example: for the parameter C (soft margin) use log2space to generate 
%          (say 5) different C values to test
%          xval_acc=svmtrain(labels_train,bof_train,'-t 0 -v 5');


% LINEAR SVM
if do_svm_linar_classification
    % cross-validation
    C_vals=log2space(7,10,5);
    for i=1:length(C_vals);
        opt_string=['-t 0  -v 5 -c ' num2str(C_vals(i))];
        xval_acc(i)=svmtrain(labels_train,new_bof_train,opt_string);
    end
    %select the best C among C_vals and test your model on the testing set.
    [v,ind]=max(xval_acc);

    % train the model and test
    model=svmtrain(labels_train,bof_train,['-t 0 -c ' num2str(C_vals(ind))]);
    disp('*** SVM - linear (test) ***');
    svm_lab_test=svmpredict(labels_test,new_bof_test,model); 
    method_name='SVM linear';
    % Compute classification accuracy
    compute_accuracy(data,labels_test,svm_lab_test,classes,method_name,desc_test,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);

    disp('*** SVM - linear (validation set) ***');
    svm_lab_val=svmpredict(labels_val,bof_val,model);
    method_name='SVM linear';
    % Compute classification accuracy
    compute_accuracy(data,labels_val,svm_lab_val,classes,method_name,desc_val,...
                      visualize_confmat & have_screen,... 
                      visualize_res & have_screen);
end

%% LLC LINEAR SVM (non rivisitato per validation)
if do_svm_llc_linar_classification
    % cross-validation
    C_vals=log2space(7,10,5);
    for i=1:length(C_vals);
        opt_string=['-t 0  -v 5 -c ' num2str(C_vals(i))];
        xval_acc(i)=svmtrain(labels_train,llc_train,opt_string);
    end
    %select the best C among C_vals and test your model on the testing set.
    [v,ind]=max(xval_acc);

    % train the model and test
    model=svmtrain(labels_train,llc_train,['-t 0 -c ' num2str(C_vals(ind))]);
    disp('*** SVM - linear LLC max-pooling ***');
    svm_llc_lab=svmpredict(labels_test,llc_test,model);
    method_name='llc+max-pooling';
    compute_accuracy(data,labels_test,svm_llc_lab,classes,method_name,desc_test,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);    
end


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%   EXERCISE 4: Image classification: SVM classifier                      %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Pre-computed LINEAR KERNELS. 
% Repeat linear SVM image classification; let's try this with a 
% pre-computed kernel.
%
% TODO:
% 4.1 Compute the kernel matrix (i.e. a matrix of scalar products) and
%     use the LIBSVM precomputed kernel interface.
%     This should produce the same results.


if do_svm_precomp_linear_classification
    % compute kernel matrix
    Ktrain = new_bof_train*new_bof_train';
    Ktest = new_bof_test*new_bof_train';
    Kval = bof_val*bof_train';

    % cross-validation
    C_vals=log2space(7,10,5);
    for i=1:length(C_vals);
        opt_string=['-t 4  -v 5 -c ' num2str(C_vals(i))];
        xval_acc(i)=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],opt_string);
    end
    [v,ind]=max(xval_acc);
    
    % train the model and test
    model=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],['-t 4 -c ' num2str(C_vals(ind))]);
    % we supply the missing scalar product (actually the values of 
    % non-support vectors could be left as zeros.... 
    % consider this if the kernel is computationally inefficient.
    disp('*** SVM - precomputed linear kernel (test) ***');
    precomp_svm_lab_test =svmpredict(labels_test,[(1:size(Ktest,1))' Ktest],model);
    method_name='SVM precomp linear';
    % Compute classification accuracy
    compute_accuracy(data,labels_test,precomp_svm_lab_test,classes,method_name,desc_test,...
                      visualize_confmat & have_screen,... 
                      visualize_res & have_screen);
    % result is the same??? must be!

    disp('*** SVM - precomputed linear kernel (validation) ***');
    precomp_svm_lab_val =svmpredict(labels_val,[(1:size(Kval,1))' Kval],model);
    compute_accuracy(data,labels_val,precomp_svm_lab_val,classes,method_name,desc_val,...
                      visualize_confmat & have_screen,... 
                      visualize_res & have_screen);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 4.1                                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% Pre-computed NON-LINAR KERNELS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% TODO:
% 4.2 Train the SVM with a precomputed non-linear histogram intersection 
%     kernel and select the best C parameter for the trained model using  
%     cross-validation.
% 4.3 Experiment with other different non-linear kernels: RBF and Chi^2.
%     Chi^2 must be precomputed as in the previous exercise.
% 4.4 Certain kernels have other parameters (e.g. gamma for RBF/Chi^2)... 
%     implement a cross-validation procedure to select the optimal 
%     parameters (as in 3).


%% 4.2: INTERSECTION KERNEL (pre-compute kernel) %%%%%%%%%%%%%%%%%%%%%%%%%%
% try a non-linear svm with the histogram intersection kernel!

if do_svm_inter_classification
    Ktrain=zeros(size(new_bof_train,1),size(new_bof_train,1));
    for i=1:size(new_bof_train,1)
        for j=1:size(new_bof_train,1)
            hists = [new_bof_train(i,:);new_bof_train(j,:)];
            Ktrain(i,j)=sum(min(hists));
        end
    end

    Ktest=zeros(size(new_bof_test,1),size(new_bof_train,1));
    for i=1:size(new_bof_test,1)
        for j=1:size(new_bof_train,1)
            hists = [new_bof_test(i,:);new_bof_train(j,:)];
            Ktest(i,j)=sum(min(hists));
        end
    end

    Kval=zeros(size(bof_val,1),size(bof_train,1));
    for i=1:size(bof_val,1)
        for j=1:size(bof_train,1)
            hists = [bof_val(i,:);bof_train(j,:)];
            Kval(i,j)=sum(min(hists));
        end
    end

    % cross-validation
    C_vals=log2space(3,10,5);
    for i=1:length(C_vals);
        opt_string=['-t 4  -v 5 -c ' num2str(C_vals(i))];
        xval_acc(i)=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],opt_string);
    end
    [v,ind]=max(xval_acc);

    % train the model and test
    model=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],['-t 4 -c ' num2str(C_vals(ind))] );
    % we supply the missing scalar product (actually the values of non-support vectors could be left as zeros.... consider this if the kernel is computationally inefficient.
    disp('*** SVM - intersection kernel (test) ***');
    [precomp_ik_svm_lab_test,conf_test]=svmpredict(labels_test,[(1:size(Ktest,1))' Ktest],model);
    method_name='SVM IK';
    % Compute classification accuracy
    compute_accuracy(data,labels_test,precomp_ik_svm_lab,classes,method_name,desc_test,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);

    disp('*** SVM - intersection kernel (val) ***');
    [precomp_ik_svm_lab_val,conf_val]=svmpredict(labels_val,[(1:size(Kval,1))' Kval],model);
    method_name='SVM IK';
    % Compute classification accuracy
    compute_accuracy(data,labels_val,precomp_ik_svm_lab_val,classes,method_name,desc_val,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 4.2                                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% 4.3 & 4.4: CHI-2 KERNEL (pre-compute kernel) %%%%%%%%%%%%%%%%%%%%%%%%%%%
%aggiornato al validation set
if do_svm_chi2_classification    
    % compute kernel matrix
    Ktrain = kernel_expchi2(new_bof_train,new_bof_train);
    Ktest = kernel_expchi2(new_bof_test,new_bof_train);
    Kval = kernel_expchi2(new_bof_val,new_bof_train);
    
    % cross-validation
    C_vals=log2space(2,10,5);
    for i=1:length(C_vals);
        opt_string=['-t 4  -v 5 -c ' num2str(C_vals(i))];
        xval_acc(i)=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],opt_string);
    end
    [v,ind]=max(xval_acc);

    % train the model and test
    model=svmtrain(labels_train,[(1:size(Ktrain,1))' Ktrain],['-t 4 -c ' num2str(C_vals(ind))] );
    % we supply the missing scalar product (actually the values of non-support vectors could be left as zeros.... 
    % consider this if the kernel is computationally inefficient.
    disp('*** SVM - Chi2 kernel (test set)***');
    [precomp_chi2_svm_lab_test,conf_test]=svmpredict(labels_test,[(1:size(Ktest,1))' Ktest],model);
    method_name='SVM Chi2';
    % Compute classification accuracy
    compute_accuracy(data,labels_test,precomp_chi2_svm_lab_test,classes,method_name,desc_test,...
                      1,... 
                      do_visualize_res & do_have_screen);


    disp('*** SVM - Chi2 kernel (validation set) ***');
    [precomp_chi2_svm_lab_val,conf_val]=svmpredict(labels_val,[(1:size(Kval,1))' Kval],model);
    method_name='SVM Chi2';
    % Compute classification accuracy
    compute_accuracy(data,labels_val,precomp_chi2_svm_lab_val,classes,method_name,desc_val,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);
    [precomp_chi2_svm_lab_train,conf_train]=svmpredict(labels_train,[(1:size(Ktrain,1))' Ktrain],model);
    compute_accuracy(data,labels_train,precomp_chi2_svm_lab_train,classes,method_name,desc_train,...
                      do_visualize_confmat & do_have_screen,... 
                      do_visualize_res & do_have_screen);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   End of EXERCISE 4.3 and 4.4                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

