function hex=file_sha256(path)
fid=fopen(path,'rb'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8'); digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
hex=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
