$server = "svm1"
$shares = @(
 "vol29","vol59","vol1_a","vol2_a","vol0_a","vol1_b","vol44","vol18","vol17",
 "vol26","vol60","vol32","vol2_b","vol3","vol5","vol9","vol56","vol16","vol34","vol55",
 "vol0_b","vol28","vol20","vol27","vol52","vol14","vol53","vol57","vol10","vol19","vol25",
 "vol54","vol24","vol30","vol49","vol13","vol11","vol51","vol15","vol31","vol45","vol58",
 "vol35","vol8","vol46","vol33","vol48","vol36","vol37","volfj13"
)

foreach ($s in $shares) {
    net use "\\$server\$s" /persistent:yes
}
