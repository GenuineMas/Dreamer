
import UIKit
import CoreBluetooth





let heartRateServiceCBUUID = CBUUID(string: "180D") // the UUID for the Heart Rate service(probabile in hexodecimal phorme)
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37") //the UUID for the Heart Rate service Characteristic
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A39")
let alarmingMiBand2 = CBUUID(string: "2A06")
/*
 2A44: properties contains .read
 2A44: properties contains .notify
 2A37: properties contains .notify
 2A39: properties contains .read
 */
let bluetoothChar = CBUUID(string: "FFE1")

class SleepDataModel: UIViewController  {
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var alarmCharacteristic : CBCharacteristic?
    var arduinoDevice : CBPeripheral!
    var conectedPeriferals = [String : CBPeripheral]()
    var sleepData = [Int]()
    
    @IBOutlet weak var numberLabel: UILabel!
    @IBAction func alarmVibration(_ sender: Any) {
        alarmingMiBand()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)    // initialization of the centralManager
        // Make the digits monospaces to avoid shifting when the numbers change
        numberLabel.font = UIFont.monospacedDigitSystemFont(ofSize: numberLabel.font!.pointSize, weight: .regular)
    }
    
    func onHeartRateReceived(_ heartRate: Int) {
        numberLabel.text = String(heartRate)
        print("BPM: \(heartRate)")
    }
    
    @IBAction func refreshChart(_ sender: UIButton) {
        let dataEntries = generateDataEntries()
        basicBarChart.dataEntries = dataEntries
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        let dataEntries = generateDataEntries()
//        basicBarChart.dataEntries = dataEntries
//
//    }

     @IBOutlet weak var basicBarChart: BasicBarChart!
}

extension SleepDataModel: CBCentralManagerDelegate {
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
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//            print(peripheral.identifier)
//            print(peripheral.name)
//
        conectedPeriferals.updateValue(peripheral, forKey: peripheral.name ?? "Nothing")
        print(conectedPeriferals)
        if peripheral.name == "MI Band 2" {
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


extension SleepDataModel: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            // print(characteristic)
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
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
                sleepData.append(number)
                 print(sleepData)
                
            }
//            if let number = characteristic.value!.uint16 as UInt16?  {
//                print(number)
//            }
            
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    
    func alarmingMiBand() {
        conectedPeriferals["MI Band 2"]?.writeValue(Data(bytes:[0x2]), for: alarmCharacteristic!, type: .withoutResponse)
    }
    
    
     //MARK: Graph
    
  
    
    

    func generateDataEntries() -> [BarEntry] {
        var value = sleepData.last
        print("The current value \(value)")
        let colors = [#colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1), #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1), #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1), #colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1), #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1)]
        var result: [BarEntry] = []
        for i in 0..<sleepData.count {
            let value = (value ?? 5 % 9000) + 10
            let height: Float = Float(value) / 100.0
            
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            var date = Date()
            date.addTimeInterval(TimeInterval(24*60*60*i))
            result.append(BarEntry(color: colors[i % colors.count], height: height, textValue: "\(value)", title: formatter.string(from: date)))
        }
        return result
    }
}



