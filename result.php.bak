<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>ITMO544</title>
</head>
<body>

<?php
#// In PHP versions earlier than 4.1.0, $HTTP_POST_FILES should be used instead
// of $_FILS.

$uploaddir = 'uploads/';
$uploadfile = $uploaddir . basename($_FILES['userfile']['name']);

if (move_uploaded_file($_FILES['userfile']['tmp_name'], $uploadfile)) {
    echo "File is valid, and was successfully uploaded.\n";
} else {
    echo "Possible file upload attack!\n";
}

echo 'Here is some more debugging info:';
print_r($_FILES);

echo "</p>";
echo $uploaddir;
echo "</p>";
echo $uploadfile;


require 'vendor/autoload.php';

use Aws\S3\S3Client;

$client = S3Client::factory();

$bucket = uniqid("image-uploader1234", true);
echo "Creating bucket named {$bucket}\n";
$result = $client->createBucket(array(
    'Bucket' => $bucket
));

$client->waitUntilBucketExists(array('Bucket' => $bucket));


// Upload an object by streaming the contents of a file
// $pathToFile should be absolute path to a file on disk

echo "Creating a new object with key";

$result = $client->putObject(array(
    'Bucket'     => $bucket,
    'Key'        => 'imageupload',
    'SourceFile' => $uploadfile,
    
));

// We can poll the object until it is accessible
$client->waitUntil('ObjectExists', array(
    'Bucket' => $bucket,
    'Key'    => 'imageupload'
));

echo "<img src=\"$uploadfile\" alt=\"picture\" height=\"100\" width=\"100\">";

?>

</body>
</html>

