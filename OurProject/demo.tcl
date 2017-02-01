#===================================
#     Simulation parameters setup
#===================================
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
set val(x)      1000                     ;# X dimension of topography
set val(y)      1000                      ;# Y dimension of topography
set val(stop)   200.0                        ;# time of simulation end
set val(energymodel)    EnergyModel     ;
set val(initialenergy) 100
set round 		1
set MESSAGE_PORT 42 

#===================================
#        Initialization        
#===================================
#Create a ns simulator
set ns [new Simulator]

#Setup topography object
set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)
create-god $val(nn)

# Create the trace files
set tracefile [open out.tr w]
$ns trace-all $tracefile

# Create the nam files
set namfile [open out.nam w]
$ns namtrace-all $namfile
$ns namtrace-all-wireless $namfile $val(x) $val(y)
set chan [new $val(chan)];#Create wireless channel


#===================================
#     Mobile node parameter setup
#===================================
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


set area [expr $val(x)*$val(y)]
set area_per_node [ expr $area / $val(nn) ]
set area_for_square [expr $area_per_node * 4]
set side_float [expr sqrt($area_for_square)]
set side [expr int($side_float)]
puts $side


#===================================
#        Nodes Definition        
#===================================
set count 0
for {set i 0} {$i < $val(x)} {incr i $side} {
	for { set j 0} {$j < $val(y)} {incr j $side} {
		for { set k 0} {$k < 4} {incr k} {
			set n_($count) [$ns node]
			$n_($count) set X_ [expr {int(rand()*($side-1)+$i)}]
			$n_($count) set Y_ [expr {int(rand()*($side-1)+$j)}]
			$n_($count) set Z_ 0.0
			incr count
		}
	}
}



#===================================
#      setting Up Sink       
#===================================
for {set i 0} { $i<$val(nn)} {incr i} {
	set sink($i) [new Agent/LossMonitor]
}


#===================================
#      setting Up TCP       
#===================================
for {set i 0} { $i<$val(nn)} {incr i} {
	set tcp($i) [new Agent/TCP]
}
 

 
 
for {set i 1} {$i < $val(nn) } {incr i} { 
	$ns attach-agent $n_($i) $sink($i)
	$ns attach-agent $n_($i) $tcp($i)

	set cbr_($i) [new Application/Traffic/CBR]

	$cbr_($i) set packetSize_ 500
	$cbr_($i) set interval_ 0.005
	$cbr_($i) attach-agent  $tcp($i)

   	$ns attach-agent $tcp($i) $sink($i)

   	$ns connect $tcp($i) $sink([expr $i-1])
   	$ns at 1.0 "$cbr_($i) start"
   	$ns at 124.0 "$cbr_($i) stop"
}


#$ns duplex-link $n0 $n2 10Mb 10ms DropTail
#$ns duplex-link $n0 $n3 20Mb 10ms DropTail
# Set queue size of the link
#$ns queue-limit $n0 $n2 20

# Setting a TCP connection
#set tcp [new Agent/TCP]
#$ns attach-agent $n0 $tcp
#set sink [new Agent/TCPSink]
#$ns attach-agent $n3 $sink
#$ns connect $tcp $sink
#$tcp set fid_ 1
#$tcp set packetSize_ 552

# Defining the 'finish' procedure'
proc finish {} {
global ns tracefile namfile
$ns flush-trace
puts "running nam..."
close $tracefile
close $namfile
exec nam out.nam &
exit 0
}

# End the program
$ns at 125.0 "finish"

# Start the the simulation process
$ns run


