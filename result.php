
<?php
// Start the session
session_start();
// In PHP versions earlier than 4.1.0, $HTTP_POST_FILES should be used instead
// of $_FILES.

//echo $_POST['useremail'];

$uploaddir = '/tmp/';
$uploadfile = $uploaddir . basename($_FILES['userfile']['name']);

echo '<pre>';
if (move_uploaded_file($_FILES['userfile']['tmp_name'], $uploadfile)) {
    echo "File is valid, and was successfully uploaded.\n";
} else {
    echo "Possible file upload attack!\n";
}

echo 'Here is some more debugging info:';
print_r($_FILES);

print "</pre>";
require 'vendor/autoload.php';
use Aws\S3\S3Client;

$client = S3Client::factory();
$bucket = uniqid("php-jrh-",false);

$result = $client->createBucket(array(
    'Bucket' => $bucket
));


$client->waitUntilBucketExists(array('Bucket' => $bucket));
$key = $uploadfile;
$result = $client->putObject(array(
    'ACL' => 'public-read',
    'Bucket' => $bucket,
    'Key' => $key,
    'SourceFile' => $uploadfile 
));
$url = $result['ObjectURL'];
echo $url;

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


/* Prepared statement, stage 1: prepare */
if (!($stmt = $link->prepare("INSERT INTO items (id, email,phone,filename,s3rawurl,s3finishedurl,status,issubscribed) VALUES (NULL,?,?,?,?,?,?,?)"))) {
    echo "Prepare failed: (" . $link->errno . ") " . $link->error;
}

$email =$_POST['useremail'];
$phone = $_POST['phone'];
$s3rawurl = $url; //  $result['ObjectURL']; from above
$filename = basename($_FILES['userfile']['name']);
$s3finishedurl = "none";
$status =0;
$issubscribed=0;

$stmt->bind_param("sssssii",$email,$phone,$filename,$s3rawurl,$s3finishedurl,$status,$issubscribed);

if (!$stmt->execute()) {
    echo "Execute failed: (" . $stmt->errno . ") " . $stmt->error;
}

printf("%d Row inserted.\n", $stmt->affected_rows);

/* explicit close recommended */
$stmt->close();

$link->real_query("SELECT * FROM items");
$res = $link->use_result();

echo "Result set order...\n";
while ($row = $res->fetch_assoc()) {
    echo $row['id'] . " " . $row['email']. " " . $row['phone'];
}


// Include the SDK using the Composer autoloader
//require 'vendor/autoload.php';

use Aws\Sns\SnsClient;


$client = SnsClient::factory(array(
'region'  => 'us-east-1'
));

$sql = "SELECT issubscribed FROM items WHERE phone = \"$phone\"";
$snscheck = "";
if ($res0 = mysqli_query($link, $sql)) {
	$row = mysqli_fetch_row($res0);
	$snscheck = $row[0];
}

$id="";

if ($snscheck == 0){
	echo "Subscribing you to recieve notification";

	$result = $client->subscribe(array(
	// TopicArn is required
	'TopicArn' => 'arn:aws:sns:us-east-1:666198007909:ma5notification',
	// Protocol is required
	'Protocol' => 'sms',
	'Endpoint' => '$phone',
	));
	
	//* Update database field issubscribed to 1 to indicate that user is already subscribed
	
	$sql = "SELECT MAX(id) AS id FROM items";

	if ($res1 = mysqli_query($link, $sql)) {
		$row = mysqli_fetch_row($res1);
		$id = $row[0];
		echo "$id test id";
	}
	
	// Create variable to set issubscribed value to 1 
	
	$sql="UPDATE items SET issubscribed=1 WHERE ID=$id";                     
        mysqli_query($link,$sql);
	echo $id;
	echo "results updated";
	
} else {
	echo "Already subscribed";
	 $sql = "SELECT MAX(id) AS id FROM items";

        if ($res1 = mysqli_query($link, $sql)) {
                $row = mysqli_fetch_row($res1);
                $id = $row[0];
                echo "$id test id";
        }
	
	// Create variable to set issubscribed value to 1 
	$sql="UPDATE items SET issubscribed=1 WHERE ID=$id";
	mysqli_query($link,$sql);
	echo $id;	
	echo "results updated yup";
}

//adding ID to queue. First getting max ID from sql statement and then putting ID in queue

echo "adding id to queue";

$currentid = "";

$sql = "SELECT MAX(id) AS id FROM items";
if ($res1 = mysqli_query($link, $sql)) {
	$row = mysqli_fetch_row($res1);
	$currentid = $row[0];}

use Aws\Sqs\SqsClient;

$client = SqsClient::factory(array(
    'region'  => 'us-east-1'
));


$client->sendMessage(array(
    'QueueUrl'    => 'https://sqs.us-east-1.amazonaws.com/666198007909/ma5queue',
    'MessageBody' => $currentid,
));



$link->close();
?>



