
###############################################################
############### Get Events ###############
LAST SEEN   TYPE      REASON              OBJECT                                          MESSAGE
55m         Normal    ScalingReplicaSet   deployment/siacx-frontend-curadoria             Scaled up replica set siacx-frontend-curadoria-c5b798d7b to 1
55m         Normal    SuccessfulCreate    replicaset/siacx-frontend-curadoria-c5b798d7b   Created pod: siacx-frontend-curadoria-c5b798d7b-jbhks
55m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-jbhks    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
45m         Normal    NotTriggerScaleUp   pod/siacx-frontend-curadoria-c5b798d7b-jbhks    pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 max node group size reached
50m         Normal    NotTriggerScaleUp   pod/siacx-frontend-curadoria-c5b798d7b-jbhks    pod didn't trigger scale-up: 1 max node group size reached, 1 node(s) had untolerated taint {CriticalAddonsOnly: true}
45m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-jbhks    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
5m24s       Normal    ScalingReplicaSet   deployment/siacx-frontend-curadoria             Scaled down replica set siacx-frontend-curadoria-c5b798d7b to 0 from 1
40m         Normal    SuccessfulDelete    replicaset/siacx-frontend-curadoria-c5b798d7b   Deleted pod: siacx-frontend-curadoria-c5b798d7b-jbhks
40m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-jbhks    skip schedule deleting pod: siacx-frontend-curadoria/siacx-frontend-curadoria-c5b798d7b-jbhks
40m         Normal    SuccessfulCreate    replicaset/siacx-frontend-curadoria-c5b798d7b   Created pod: siacx-frontend-curadoria-c5b798d7b-gfz4p
5m14s       Normal    ScalingReplicaSet   deployment/siacx-frontend-curadoria             Scaled up replica set siacx-frontend-curadoria-c5b798d7b to 1 from 0
40m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-gfz4p    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
15m         Normal    NotTriggerScaleUp   pod/siacx-frontend-curadoria-c5b798d7b-gfz4p    pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 max node group size reached
15m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-gfz4p    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
13m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-gfz4p    skip schedule deleting pod: siacx-frontend-curadoria/siacx-frontend-curadoria-c5b798d7b-gfz4p
13m         Normal    SuccessfulDelete    replicaset/siacx-frontend-curadoria-c5b798d7b   Deleted pod: siacx-frontend-curadoria-c5b798d7b-gfz4p
13m         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-vd22b    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
13m         Normal    SuccessfulCreate    replicaset/siacx-frontend-curadoria-c5b798d7b   Created pod: siacx-frontend-curadoria-c5b798d7b-vd22b
8m44s       Normal    NotTriggerScaleUp   pod/siacx-frontend-curadoria-c5b798d7b-vd22b    pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 max node group size reached
8m40s       Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-vd22b    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
5m23s       Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-vd22b    skip schedule deleting pod: siacx-frontend-curadoria/siacx-frontend-curadoria-c5b798d7b-vd22b
5m24s       Normal    SuccessfulDelete    replicaset/siacx-frontend-curadoria-c5b798d7b   Deleted pod: siacx-frontend-curadoria-c5b798d7b-vd22b
5m14s       Normal    SuccessfulCreate    replicaset/siacx-frontend-curadoria-c5b798d7b   Created pod: siacx-frontend-curadoria-c5b798d7b-zx9d2
5m13s       Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-zx9d2    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
2s          Normal    NotTriggerScaleUp   pod/siacx-frontend-curadoria-c5b798d7b-zx9d2    pod didn't trigger scale-up: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 1 max node group size reached
10s         Warning   FailedScheduling    pod/siacx-frontend-curadoria-c5b798d7b-zx9d2    0/3 nodes are available: 1 node(s) had untolerated taint {CriticalAddonsOnly: true}, 2 Insufficient cpu. preemption: 0/3 nodes are available: 1 Preemption is not helpful for scheduling, 2 No preemption victims found for incoming pod.
