<?php
// Proxy script to bypass CORS restrictions

// Enable error logging for debugging
ini_set('log_errors', 1);
error_reporting(E_ALL);
ini_set('error_log', '/path/to/your/error.log'); // Specify the path to your error log file

// Define the URL of the KPFT API you're trying to access
// To switch between HD1 and HD2 metadata, use one of these URLs:
// HD1: https://confessor.kpft.org/playlist/_pl_current_ary.php
// HD2: https://hd3.kpft.org/playlist/_pl_current_ary.php
$kpftApiUrl = 'https://confessor.wpfwfm.org/playlist/_pl_current_ary.php';

// Use cURL to make the API request
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $kpftApiUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HEADER, false);

// Set a reasonable timeout for the cURL request
curl_setopt($ch, CURLOPT_TIMEOUT, 10); // 10 seconds timeout

$response = curl_exec($ch);

// Check if the response size is too large
if (strlen($response) > 1000000) { // Limit response size to 1MB for example
    header('HTTP/1.1 413 Payload Too Large');
    echo json_encode(['error' => 'Response too large.']);
    curl_close($ch);
    exit;
}

// Check if the cURL call failed and return an error message
if ($response === false) {
    $error = curl_error($ch);
    header('HTTP/1.1 502 Bad Gateway');
    echo json_encode(['error' => 'Failed to fetch data from KPFT API.', 'curl_error' => $error]);
    curl_close($ch);
    exit;
}

curl_close($ch);

// Set CORS headers
header('Access-Control-Allow-Origin: *'); // Adjust as per your CORS policy

// Set the Content-Type header to application/json
header('Content-Type: application/json');

// Echo the response from the KPFT API call
echo $response;
