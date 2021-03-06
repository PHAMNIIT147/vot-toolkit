function [transformed_sequence] = sequence_pixelchange(sequence, operation, name)
% sequence_pixelchange Returns sequence with arbitrary pixel transformation
%
% This sequence converter returns sequence with arbitrary pixel transformation that preserves the
% size of the image and the groundtruth.
%
% Cache notice: The results of this function are cached in the workspace cache directory.
%
% Input:
% - sequence (structure): A valid sequence structure.
% - operation (function): A handle of the pixel transformation function.
% - name (string, optional): Name of the operation for caching purposes.
%
% Output:
% - tranform_sequence (structure): A sequence descriptor of a converted sequence.

if ischar(operation)
    operation_name = operation;
    operation = str2func(operation_name);
else
    operation_name = func2str(operation);
end;

if ~isempty(name) && ischar(name)
    operation_name = name;
end;

cache_directory = fullfile(get_global_variable('directory'), 'cache', ...
    sprintf('pixelchange_%s', operation_name), sequence.name);

mkpath(cache_directory);

cache_groundtruth = fullfile(cache_directory, 'groundtruth.txt');

sequence_groundtruth = fullfile(sequence.directory, 'groundtruth.txt');

if file_newer_than(cache_groundtruth, sequence_groundtruth)
    transformed_sequence = sequence_create(cache_directory, 'name', sequence.name);
    transformed_sequence.values.names = sequence.values.names;
    transformed_sequence.values.data = sequence.values.data;
    return;
end;

print_debug('Generating cached sequence ''%s'' for operation ''%s''...', sequence.name, operation_name);

tags_cache_names = cell(0, 0);
tags_cache_data = false(sequence.length, 0);

for i = 1:sequence.length

    original_image = imread(sequence_get_image(sequence, i));
    original_tags = get_tags(sequence, i);

    [transformed_image, transformed_tags] = operation(original_image, ...
        original_tags, i, sequence.length);

    for l = 1:length(transformed_tags)
        if ~ismember(transformed_tags{l}, tags_cache_names)
            tags_cache_data = cat(2, tags_cache_data, false(sequence.length, 0));
            tags_cache_names{end+1} = transformed_tags{l};  %#ok<AGROW>
        end;
        tags_cache_data(i, strcmp(tags_cache_names, transformed_tags{l})) = 1;
    end;

    if size(transformed_image, 3) == 1
        transformed_image = repmat(rgb2gray(transformed_image), [1 1 3]);
    end;

    if size(original_image, 1) ~= size(transformed_image, 1) || ...
            size(original_image, 2) ~= size(transformed_image, 2)
        error('The operation should return image of same width and height.');
    end;

    imwrite(transformed_image, fullfile(cache_directory, sprintf('%08d.jpg', i)));

end;

for l = 1:length(tags_cache_names)
    csvwrite(fullfile(cache_directory, sprintf('%s.tag', ...
        tags_cache_names{l})), tags_cache_data(:, l));
end;

write_trajectory(cache_groundtruth, sequence.groundtruth);

transformed_sequence = sequence_create(cache_directory, 'name', sequence.name);

transformed_sequence.values.names = sequence.values.names;
transformed_sequence.values.data = sequence.values.data;

