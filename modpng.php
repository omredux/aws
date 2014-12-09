<?php

function LoadPng($imgname)
{
    /* Attempt to open */
    $im = @imagecreatefrompng($imgname);

    /* See if it failed */
    if(!$im)
    {
        /* Create a black image */
        $im  = imagecreatetruecolor(150, 30);
        $bgc = imagecolorallocate($im, 255, 255, 255);
        $tc  = imagecolorallocate($im, 0, 0, 0);

        imagefilledrectangle($im, 0, 0, 150, 30, $bgc);

        /* Output an error message */
        imagestring($im, 1, 5, 5, 'Error loading ' . $imgname, $tc);
    }

    return $im;
}


require 'vendor/autoload.php';
use Aws\Rds\RdsClient;
$client = RdsClient::factory(array(
'region'  => 'us-east-1'
));

$result = $client->describeDBInstances(array(
    'DBInstanceIdentifier' => 'dbtest',
));

$endpoint = "";

foreach ($result->getPath('DBInstances/*/Endpoint/Address') as $ep) {
    // Do something with the message
    echo "============". $ep . "================";
    $endpoint = $ep;
}   
//echo "begin database";
$link = mysqli_connect($ep,"Dktest","letmein12","Testdb") or die("Error " . mysqli_error($link));

/* check connection */
if (mysqli_connect_errno()) {
    printf("Connect failed: %s\n", mysqli_connect_error());
    exit();
}


use Aws\Sqs\SqsClient;

$client = SqsClient::factory(array(
    'region'  => 'us-east-1'
));


$result = $client->receiveMessage(array(
	'QueueUrl' => 'https://sqs.us-east-1.amazonaws.com/666198007909/ma5queue',
	'MaxNumberOfMessages' => 1,	
));

$messageBody = "";
$receiptHandle = "";
$rawsqsurl = "";
//get queue messages and row ID

foreach ($result->getPath('Messages/*/Body') as $messageBody) {
	$sql = "SELECT s3rawurl FROM items WHERE id = $messageBody";
	echo $sql;
	if ($res1 = mysqli_query($link, $sql)) {
		$rawsqsurl = mysqli_fetch_row($res1);
		echo $rawsqsurl[0];
	}

    
}

//get reciepthandle

foreach ($result->getPath('Messages/*/ReceiptHandle') as $receiptHandle) {}


//modify image 

header('Content-Type: image/png');

$img = LoadPng("$rawsqsurl");

imagepng($img,"/tmp/g5.png");
//imagedestroy($img);

//delete queue message with queueurl and reciepthandle

$result = $client->deleteMessage(array(
    // QueueUrl is required
    'QueueUrl' => 'https://sqs.us-east-1.amazonaws.com/666198007909/ma5queue',
    // ReceiptHandle is required
    'ReceiptHandle' => $receiptHandle,
));

//upload file to new bucket 

use Aws\S3\S3Client;

$client = S3Client::factory();

$bucket = uniqid("ma5image-uploader1234", true);

echo "Creating bucket named {$bucket}\n";
$result = $client->createBucket(array(
    'Bucket' => $bucket
));

$client->waitUntilBucketExists(array('Bucket' => $bucket));


// Upload an object by streaming the contents of a file
// $pathToFile should be absolute path to a file on disk

echo "Creating a new object with key";

$result = $client->putObject(array(
	'ACL' => 'public-read',
	'Bucket' => $bucket,
	'Key' => 'imageupload',
	'SourceFile' => 'tmp/g5.png'  
));

// We can poll the object until it is accessible
$client->waitUntil('ObjectExists', array(
    'Bucket' => $bucket,
    'Key'    => 'imageupload'
));

// get s3finishedurl

$s3finishedurl = $result['ObjectURL'];
echo $s3finishedurl; 
//update values in database

$status = 1;

$query = "UPDATE items SET status=?, s3finishedurl WHERE id=?";
$statement = $mysqli->prepare($query);

//bind parameters for markers, where (s = string, i = integer, d = double,  b = blob)
$results =  $statement->bind_param('isi', $status, $s3finishedurl, $messageBody );

//notify user with SNS 

use Aws\Sns\SnsClient;

$client = SnsClient::factory(array(
    'region'  => 'us-east-1'
));

//publish message 

$result = $client->publish(array(
    'TopicArn' => 'arn:aws:sns:us-east-1:666198007909:ma5notification',
    // Message is required
    'Message' => 'Processed image is available at $url'
));

?>
