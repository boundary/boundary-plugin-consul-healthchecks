Queries Consul health checks and returns events to Boundary on a status change of a given health check. 

### Prerequisites

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |   v   |    v    |    v    |  v   |

#### Boundary Meter versions v4.2 or later 

- To install new meter go to Settings->Installation or [see instructions](https://help.boundary.com/hc/en-us/sections/200634331-Installation).
- To upgrade the meter to the latest version - [see instructions](https://help.boundary.com/hc/en-us/articles/201573102-Upgrading-the-Boundary-Meter).

### Plugin Setup

None

#### Plugin Configuration Fields

|Field Name          |Description                                                                                                           |
|:-------------------|:---------------------------------------------------------------------------------------------------------------------|
|Poll Interval (sec) |The Poll Interval to call your endpoint in seconds. Ex. 30                                                            |
|Detailed Info       |(optional) Set to true to display additional info on passing health checks  (default = not set i.e. false)            |

### Metrics Collected

|Metric Name                |Description                                       |
|:--------------------------|:-------------------------------------------------|
|Health Check State Changes |Number of Consul health checks whose state changed|


### Dashboards

None

### References

None
