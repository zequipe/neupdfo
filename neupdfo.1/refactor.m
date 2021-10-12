function refactor(files)

if nargin < 1 || isempty(files) || strcmpi(files, 'ALL')
    listing = dir();
    files = {listing.name};
else
    files = {files};
end

for ifile = 1 : length(files)
    filename = files{ifile};
    if endsWith(filename, '.f') || endsWith(filename, '.f90')
        fid = fopen(filename, 'r');
        data = textscan(fid, '%s', 'delimiter', '\n', 'whitespace', '');
        fclose(fid);
        cstr = data{1};
        cstr(count(cstr, 'C') == strlength(cstr)) = replace(cstr(count(cstr, 'C') == strlength(cstr)), 'C', '!');
        for jc = 1 : length(cstr)
            if startsWith(cstr{jc}, 'C')
                strt = cstr{jc};
                strt(1) = '!';
                cstr{jc} = strt;
            end
            if startsWith(cstr{jc}, '      ')
                strt = cstr{jc};
                strt = strt(7:end);
                cstr{jc} = strt;
            end
        end
        cstr(~startsWith(strtrim(cstr), '!') & ~contains(cstr, 'FORMAT')) = lower(cstr(~startsWith(strtrim(cstr), '!') & ~contains(cstr, 'FORMAT')));
        fid = fopen(filename, 'w');
        fprintf(fid, '%s\n', cstr{:});
        fclose(fid);
    end
end
