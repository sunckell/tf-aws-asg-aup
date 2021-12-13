# ---
# --- autoscaling bells and whistles
# --- https://aws.amazon.com/premiumsupport/knowledge-center/auto-scaling-group-rolling-updates/
# --- https://www.terraform.io/docs/providers/aws/r/cloudformation_stack.html
# --- https://github.com/hashicorp/terraform/issues/1552
# ---
resource "aws_cloudformation_stack" "asg" {
  name = "${var.domain}-${var.project_key}-${var.component_short_name}-cf-asg"

  template_body = <<EOF
{
 "Resources": {
    "AutoScalingGroup": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "VPCZoneIdentifier" : [
          "${tolist(data.aws_subnet_ids.private.ids)[0]}",
          "${tolist(data.aws_subnet_ids.private.ids)[1]}"
        ],
        "MaxSize": "${var.asg_max_size}",
        "MinSize": "${var.asg_min_size}",
        "DesiredCapacity": "${var.asg_desired_capacity}",
        "TerminationPolicies": ["Default"],
        "HealthCheckType": "EC2",
        "HealthCheckGracePeriod": "${var.health_check_grace_period}",
        "MetricsCollection": [
          {
            "Granularity": "1Minute",
            "Metrics": [
              "GroupMinSize",
              "GroupMaxSize",
              "GroupDesiredCapacity",
              "GroupInServiceInstances",
              "GroupPendingInstances",
              "GroupStandbyInstances",
              "GroupTerminatingInstances",
              "GroupTotalInstances"
            ]
          }
        ],
        "TargetGroupARNs" : ["${var.target_group_arn}"],
        "Tags": [
          {
            "Key": "Name",
            "Value": "${lower(var.domain)}-${lower(var.project_key)}-${lower(var.component_short_name)} ASG with Auto Update Policy",
            "PropagateAtLaunch": true
          },
          {
            "Key": "OwnerEmail",
            "Value": "${lower(var.owner_email)}",
            "PropagateAtLaunch": true
          },
          {
            "Key": "Origin",
            "Value": "Unity",
            "PropagateAtLaunch": true
          },
          {
            "Key": "Module",
            "Value": "${lower(var.module_name)}",
            "PropagateAtLaunch": true
          },
          {
            "Key": "AppId",
            "Value": "${upper(var.application_id)}",
            "PropagateAtLaunch": true
          },
          {
            "Key": "AppName",
            "Value": "${lower(var.folio_project)}",
            "PropagateAtLaunch": true
          }
        ],
      "MixedInstancesPolicy": {
          "InstancesDistribution" : {
            "OnDemandAllocationStrategy" : "prioritized",
            "OnDemandBaseCapacity" : 0,
            "OnDemandPercentageAboveBaseCapacity" : "${var.on_demand_percentage}",
            "SpotAllocationStrategy" : "capacity-optimized"
          },
          "LaunchTemplate" : {
            "LaunchTemplateSpecification" : {
              "LaunchTemplateId" : "${aws_launch_template.base.id}",
              "Version" : "${aws_launch_template.base.latest_version}"
            }
          }
        }
      },
      "UpdatePolicy": {
        "AutoScalingReplacingUpdate": {
          "WillReplace": false
        },
        "AutoScalingRollingUpdate": {
          "MinInstancesInService": "${var.asg_min_size}",
          "MaxBatchSize": "1",
          "PauseTime": "PT10M",
          "SuspendProcesses": [
            "HealthCheck",
            "ReplaceUnhealthy",
            "AZRebalance",
            "AlarmNotification",
            "ScheduledActions"
          ],
          "WaitOnResourceSignals": true
        }
      }
    }
  },
  "Outputs": {
    "AsgName": {
      "Description": "The name of the auto scaling group",
       "Value": {"Ref": "AutoScalingGroup"}
    }
  }
}
EOF

  # --- I really hate cloudformation stacks.  "They are just too unreliable." --ckell 2021
  # --- but it's the only way to get an updatepolicy applied to the auto scaling group.
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}