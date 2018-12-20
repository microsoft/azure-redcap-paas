<?php
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);
  $home = getenv('HOME');
  $stagepath = $home . '\\site\\repository\\currlogname.txt';
  $filepath = file($stagepath);
  $rows = file($filepath[0]);
?>

<html>
<head>
    <title>REDCap Deployment Status</title>
    <style type="text/css">
        #main {
            width: 70%;
            margin-left: auto;
            margin-right: auto;
            margin-top: 10px;
            border: 1px solid navy;
            border-radius: 3px;
            padding: 4px;
        }
		div.scroll {
			height:600px;
			overflow:auto;
		}
        div.main {
            font-family: consolas,courier,monospace,monospace;
            white-space: pre-wrap;
        }
		div.code {
			font-family: consolas,courier,monospace,monospace;
			background-color:#dedede;
			padding:6px;
		}
    </style>
</head>
<body>
    <div id="main">
        <h3>REDCap Setup Log</h3>
		<div class="scroll">
			<div class="main">
				<?php
				foreach($rows as &$line)
				{
				echo '<div>'.$line.'</div>';
				}
				?>
			</div>
		</div>
		<p>
		(This page is removed after the first viewing.)
		</p>
		<p>
			<a href="/">Home</a> | 
			<a href="/install.php">Review REDCap Installation (/install.php)</a>
		</p>
    </div>
</body>
</html>
<?php
  $filepath = $home . '\\site\\wwwroot\\AzDeployStatus.php';
  unlink($filepath);
?>