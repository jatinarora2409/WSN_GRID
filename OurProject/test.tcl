set val(chan)   Channel/WirelessChannel    ;# channel type
set val(prop)   Propagation/TwoRayGround   ;# radio-propagation model
set val(netif)  Phy/WirelessPhy            ;# network interface type
set val(mac)    Mac/802_11                 ;# MAC type
set val(ifq)    CMUPriQueue     ;# interface queue type
set val(ll)     LL                         ;# link layer type
set val(ant)    Antenna/OmniAntenna        ;# antenna model
set val(ifqlen) 100                         ;# max packet in ifq
set val(nn)     100                         ;# number of mobilenodes
set val(rp)     DSR                      ;# routing protocol
set val(x)      100                     ;# X dimension of topography
set val(y)      100                     ;# Y dimension of topography
set val(stop)   200.0                        ;# time of simulation end
set val(energymodel)    EnergyModel     ;
set val(initialenergy) 100
set round 		1
set MESSAGE_PORT 42 



set ns [new Simulator]

set tracefile [open tracetest.tr w]
$ns trace-all $tracefile

set namfile [open outtest.nam w]
$ns namtrace-all $namfile
set chan [new $val(chan)];


set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god (3)

$ns node-config -adhocRouting  $val(rp) \
                -llType        $val(ll) \
                -macType       $val(mac) \
                -ifqType       $val(ifq) \
                -ifqLen        $val(ifqlen) \
                -antType       $val(ant) \
                -propType      $val(prop) \
                -phyType       $val(netif) \
                -channel       $chan \
                -topoInstance  $topo \
				-energyModel $val(energymodel) \
				-idlePower 0.0 \
				-rxPower 1.0 \
				-txPower 1.0 \
	          	-sleepPower 0.001 \
    	      	-transitionPower 0.2 \
    	      	-transitionTime 0.005 \
				-initialEnergy $val(initialenergy) \
                -agentTrace    ON \
                -routerTrace   ON \
                -macTrace      ON \
                -movementTrace ON







proc finish {} {
global ns tracefile namfile
$ns flush-trace
puts "running nam..."
close $tracefile
close $namfile
exec nam outtest.nam &
exit 0
}


set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]

set tcp [new Agent/TCP]
$ns attach-agent $n0 $tcp


set sink [new Agent/TCPSink]
$ns attach-agent $n2 $sink


$ns connect $tcp $sink
$tcp set fid_ 1
$tcp set packetSize_ 552

set ftp [new Application/FTP]
$ftp attach-agent $tcp


$ns at 1.0 "$ftp start"
$ns at 124.0 "$ftp stop"
$ns at 125.0 "finish"
$ns run