function images_descs=get_descriptors_files_val(data,class_id,img_ext,desc_name,train_or_test)
    if strcmp(train_or_test,'train')
        images_descs = data(class_id).files(data(class_id).train_id);
    
    elseif strcmp(train_or_test,'val')
        images_descs = data(class_id).files(data(class_id).val_id);
        
    else
        images_descs = data(class_id).files(data(class_id).test_id);
    end
    images_descs=strrep(images_descs,img_ext,desc_name);
end