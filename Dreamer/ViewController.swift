
import UIKit
import CoreBluetooth
import Charts




let frame = CGRect(x: 0, y: 61, width: 320, height: 241)  //graph
let heartRateServiceCBUUID = CBUUID(string: "180D") // the UUID for the Heart Rate service(probabile in hexodecimal phorme)
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37") //the UUID for the Heart Rate service Characteristic
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A39")
let alarmingMiBand2 = CBUUID(string: "2A06")
let bluetoothChar = CBUUID(string: "FFE1")

class TestViewController: UIViewController,ChartViewDelegate,UIScrollViewDelegate{
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var alarmCharacteristic : CBCharacteristic?
    var arduinoDevice : CBPeripheral!
    var conectedPeriferals = [String : CBPeripheral]()
    var vibrationsCount = [Int]()
    var currentTime = [Int]()
    
    
    @IBOutlet weak var numberLabel: UILabel!
    @IBAction func alarmVibration(_ sender: Any) {
        alarmingMiBand()
    }
    @IBOutlet weak var lineChartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        //charts
        self.lineChartView.delegate = self
        let set_a: LineChartDataSet = LineChartDataSet(values:[ChartDataEntry(x: Double(0), y: Double(0))], label: "sensor")
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.blue)
        
    
        self.lineChartView.data = LineChartData(dataSets: [set_a])
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true){timer in self.updateCounter() }
        self.lineChartView.dragEnabled = true
        
        
        centralManager = CBCentralManager(delegate: self, queue: nil)    // initialization of the centralManager
        // Make the digits monospaces to avoid shifting when the numbers change
        numberLabel.font = UIFont.monospacedDigitSystemFont(ofSize: numberLabel.font!.pointSize, weight: .regular)
        
    }
    
    // add point
    var i = 1
    func updateCounter() {
        if vibrationsCount.count > 10 && i <= vibrationsCount.count-1  {
            self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(currentTime[i]), y: Double(vibrationsCount[i])), dataSetIndex: 0)
            self.lineChartView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(1000))
            self.lineChartView.notifyDataSetChanged()
            self.lineChartView.moveViewToX(Double(i))
            i = i + 1
        }
        
        
    }
    

    func onHeartRateReceived(_ heartRate: Int) {
        numberLabel.text = String(heartRate)
        print("BPM: \(heartRate)")
    }
}


extension TestViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: nil ) //Scaning( can only accept this command while in the powered on state)
        @unknown default:
            print("central.state is .poweredOFF")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        conectedPeriferals.updateValue(peripheral, forKey: peripheral.name ?? "Nothing")
        
        print(peripheral.name!)
     
        if peripheral.name == "BT05" {
            centralManager.stopScan()
            for conectPeriferal in conectedPeriferals.values{
                centralManager.connect(conectPeriferal)
                conectPeriferal.delegate = self
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        for conectPeriferal in conectedPeriferals.values{
            print(conectPeriferal.discoverServices(nil))
        }
    }
}


extension TestViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            //  print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            // print(characteristic)
            if characteristic.properties.contains(.read) {
                //print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                // print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == alarmingMiBand2 {
                alarmCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        switch characteristic.uuid {
            
        case bluetoothChar :
            if let sensorData = NSString.init(data:characteristic.value!, encoding: String.Encoding.utf8.rawValue) as String?{
                
                numberLabel.text = sensorData
                //sleepData.append(Int(characteristic.value!))
                
                let number = (sensorData as NSString).integerValue
                print(number)
                vibrationsCount.append(number)
                currentTime.append(vibrationsCount.count)
                //linePlotData = sleepData.map{(Double($0))}
                
                // print(currentTime)
                
            }
            
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    
    func alarmingMiBand() {
        conectedPeriferals["MI Band 2"]?.writeValue(Data([0x2]), for: alarmCharacteristic!, type: .withoutResponse)
    }  
}



