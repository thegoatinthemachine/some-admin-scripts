Add-PrinterDriver -Name "MS Publisher Color Printer"
Add-PrinterPort "http://$printserver:631/printers/$target_printer"
Add-Printer -Name "$target_printer_name" -PortName "http://$printserver:631/printers/$target_printer" -DriverName "MS Publisher Color Printer"
