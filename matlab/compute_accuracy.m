function compute_accuracy(data,labels_test,labels_pred,classes,method_name,desc_test,visualize_confmat,visualize_res)
    for i=1:length(data)
            ind=find(labels_test==i);
            acc_class=mean(labels_pred(ind)==labels_test(ind));
    end
    acc=mean(labels_pred==labels_test);
    CM = confmatrix(labels_test,labels_pred,length(data));
    % normalize CM considering categories for each class (e.g. in Caltech-101 
    % it is very important since some categories have few images) 
    CMnorm = CM ./ repmat( sum(CM,2), [1 size(CM,2)] );
    if (visualize_confmat)
        figure;
        if 1 %length(data) <= 15
            confmatrix_show(CMnorm, classes);
            title([method_name ' classification']);
        else
            imagesc(CMnorm);colorbar
            
        end;
    end
    acc = mean(diag(CMnorm));
    writematrix(CMnorm,'M.csv') 
    %fprintf('OVERALL %s classification accuracy: %1.4f\n\n',method_name,acc);

    %% VISUALIZE examples %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  Illustrate correcly classified and missclassified samples of each class
    if visualize_res
        fprintf('Visualize NN L2-BoW classification results\n\n');
        visualize_results_lbp( classes, desc_test, labels_test, labels_pred );
    end

    [macroF1, precision, recall, accuracy] = calculateMetrics(CMnorm, classes);
    fprintf('OVERALL %s classification accuracy: %1.4f\n\n',method_name,accuracy);
    fprintf('OVERALL %s classification precision: %1.4f\n\n',method_name,precision);
    fprintf('OVERALL %s classification recall: %1.4f\n\n',method_name,recall);
    fprintf('OVERALL %s classification macroF1: %1.4f\n\n',method_name,macroF1);
    
end