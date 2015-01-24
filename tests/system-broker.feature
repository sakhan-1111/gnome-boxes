Feature: System Broker

  Background:
    * Make sure that gnome-boxes is running
    * Wait until overview is loaded

  @connect_to_system_broker_machine
  Scenario: Connect to system broker
    * Connect to system broker
    Then Box "Core-5.3" "does" exist
    Then Go into "Core-5.3" box
    Then Press "back" in vm
    Then Box "Core-5.3" "does" exist

  @delete_system_broker_machine
  Scenario: Delete system broker machine
    * Connect to system broker
    * Select "Core-5.3" box
    * Press "Delete"
    * Close warning
    Then Box "Core-5.3" "does not" exist
    Then "Core-5.3" is not visible with command "virsh -c qemu:///system list"

  @reflect_delete_from_system_broker
  Scenario: System broker machine deleted from outside
    * Connect to system broker
    * Wait for "virsh -c qemu:///system destroy Core-5.3; virsh -c qemu:///system undefine Core-5.3" end
    Then Box "Core-5.3" "does not" exist

  @reflect_addition_from_system_broker
  Scenario: System broker machine added from outside
    * Connect to empty system broker
    * Wait for "virt-install -r 128 --name Core-5.3 --nodisks --cdrom /tmp/Core-5.3.iso --os-type linux --accelerate --connect qemu:///system --wait 0" end
    Then Box "Core-5.3" "does" exist
    Then Go into "Core-5.3" box
    Then Press "back" in vm
    Then Box "Core-5.3" "does" exist

  @undo_delete_system_broker_machine
  Scenario: Undo system broker machine delete
    * Connect to system broker
    * Select "Core-5.3" box
    * Press "Delete"
    * Press "Undo"
    Then Box "Core-5.3" "does" exist
    Then "Core-5.3" is visible with command "virsh -c qemu:///system list"

  @pause_system_broker_box
  Scenario: Pause system broker box
    * Connect to system broker
    When Ping "Core-5.3"
    * Select "Core-5.3" box
    * Press "Pause"
    * Wait for "sleep 5" end
    Then Cannot ping "Core-5.3"

  @resume_system_broker_box
  Scenario: Resume system broker box
    * Connect to system broker
    * Select "Core-5.3" box
    * Press "Pause"
    * Wait for "sleep 10" end
    * Go into "Core-5.3" box
    * Wait for "sleep 10" end
    Then Ping "Core-5.3"
    Then Press "back" in vm

  @force_shutdown_system_broker_machine
  Scenario: Force off system broker box
    * Connect to system broker
    * Select "Core-5.3" box
    * Press "Properties"
    * Press "Force Shutdown"
    * Press "Shutdown" in alert
    Then Box "Core-5.3" "does" exist
    Then Cannot ping "Core-5.3"

  @system_broker_restart_persistence
  Scenario: System broker restart persistence
    * Connect to system broker
    * Quit Boxes
    * Start Boxes
    Then Box "Core-5.3" "does" exist