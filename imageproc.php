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
use Aws\Sqs\SqsClient;
use Aws\S3\S3Client;
use Aws\Sns\SnsClient;


while(1) {

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



$client = SqsClient::factory(array(
    'region'  => 'us-east-1'
));


$result = $client->receiveMessage(array(
	'QueueUrl' => 'https://sqs.us-east-1.amazonaws.com/666198007909/ma5queue',
 	'MaxNumberOfMessages' => 1,
	'VisibilityTimeout' => 30,

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
		echo "test $rawsqsurl[0]";
	}

    
}
if(!empty($messageBody)){


//get reciepthandle


	foreach ($result->getPath('Messages/*/ReceiptHandle') as $receiptHandle) {
		echo "test";
	}


	//modify image 

	header('Content-Type: image/png');

	$img = LoadPng("$rawsqsurl[0]");
	echo "12345 $rawsqsurl[0]";
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



$client = S3Client::factory();
$bucket = uniqid("php-ma5-",false);

$result = $client->createBucket(array(
    'Bucket' => $bucket
));




// Upload an object by streaming the contents of a file
// $pathToFile should be absolute path to a file on disk

echo "Creating a new object with key";

$client->waitUntilBucketExists(array('Bucket' => $bucket));
$key = '/tmp/g5.png';
$result = $client->putObject(array(
    'ACL' => 'public-read',
    'Bucket' => $bucket,
    'Key' => $key,
    'SourceFile' => '/tmp/g5.png' 
));
// get s3finishedurl

$s3finishedurl = $result['ObjectURL'];
echo $s3finishedurl;
echo "finished url"; 
//update values in database


$results = $link->query("UPDATE items SET status=1,s3finishedurl=\"$s3finishedurl\" WHERE ID=$messageBody");



$client = SnsClient::factory(array(
    'region'  => 'us-east-1'
));

//publish message 

$result = $client->publish(array(
    'TopicArn' => 'arn:aws:sns:us-east-1:666198007909:ma5notification',
    // Message is required
    'Message' => "Processed image is available at $s3finishedurl"
));
}

sleep(60);
}

?>
