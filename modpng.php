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
//get queue messages

foreach ($result->getPath('Messages/*/Body') as $messageBody) {
	$sql = "SELECT s3rawurl FROM items WHERE id = $messageBody";
	echo $sql;
	if ($res1 = mysqli_query($link, $sql)) {
		$rawsqsurl = mysqli_fetch_row($res1);
		echo $rawsqsurl[0];
	}

    
}


header('Content-Type: image/png');

$img = LoadPng("https://php-jrh-547d759e72042.s3.amazonaws.com/tmp/Setting-icon.png");

imagepng($img,"/tmp/g5.png");
//imagedestroy($img);

delete queue message

$result = $client->deleteMessage(array(
    // QueueUrl is required
    'QueueUrl' => 'string',
    // ReceiptHandle is required
    'ReceiptHandle' => 'string',
));

s3

use Aws\S3\S3Client;

$client = S3Client::factory(array(
    'profile' => '<profile in your aws credentials file>'
));


create bucket

$client->createBucket(array('Bucket' => 'mybucket'));


upload file to bucket

// Upload an object by streaming the contents of a file
// $pathToFile should be absolute path to a file on disk
$result = $client->putObject(array(
    'Bucket'     => $bucket,
    'Key'        => 'data_from_file.txt',
    'SourceFile' => $pathToFile,
    'Metadata'   => array(
        'Foo' => 'abc',
        'Baz' => '123'
    )
));

SNS

use Aws\Sns\SnsClient;

$client = SnsClient::factory(array(
    'profile' => '<profile in your aws credentials file>',
    'region'  => '<region name>'
));

publish massage 

$result = $client->publish(array(
    'TopicArn' => 'string',
    'TargetArn' => 'string',
    // Message is required
    'Message' => 'string',
    'Subject' => 'string',
    'MessageStructure' => 'string',
    'MessageAttributes' => array(
        // Associative array of custom 'String' key names
        'String' => array(
            // DataType is required
            'DataType' => 'string',
            'StringValue' => 'string',
            'BinaryValue' => 'string',
        ),
        // ... repeated
    ),
));

?>
