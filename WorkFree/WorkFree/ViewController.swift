//
//  ViewController.swift
//  WorkFree
//
//  Created by doki on 2017/03/30.
//  Copyright © 2017年 RDG. All rights reserved.
//

import UIKit
import CoreLocation
import GoogleAPIClient
import UserNotifications
import AppAuth
import GTMAppAuth
import JWTDecode


class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    enum ActionIdentifier: String {
        //        case attend
        case absent
    }
    
    // UI Reference
    @IBOutlet weak var getCalStatusField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var importBtn: UIButton!
    
    //    var authState: OIDAuthState?
    var authorization: GTMAppAuthFetcherAuthorization?
    
    // Google Developer Consloeから取得
    private let kKeychainItemName = "WorkFree"
    private let kClientID = "536949636872-qf3q3l98o7mnen4amoqvd7ojqmadsqsh.apps.googleusercontent.com"
    private let kRedirectURI = "com.googleusercontent.apps.536949636872-qf3q3l98o7mnen4amoqvd7ojqmadsqsh:/oauthredirect"
    private let kScriptID = "Mv2ClKi8lnov7ny8gmjxXZ-dUXSWx8h9_"
    
    private let kIssuer = "https://accounts.google.com"
    
    private let scopes = [kGTLAuthScopeCalendarReadonly, "https://www.googleapis.com/auth/drive", "https://www.googleapis.com/auth/spreadsheets", "email"]
    
    private let service = GTLService()
    private let serviceCal = GTLServiceCalendar()
    
    var locationManager: CLLocationManager = CLLocationManager()
    var beaconRegion: CLBeaconRegion!
    var beaconRegionArray = [CLBeaconRegion]()
    
    
    let ud = UserDefaults.standard
    var beaconList = [NSDictionary]()
    var regionId: String = ""
    
    var beaconUUID = Array<String>()
    
    var uuid: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var majorValue = CLBeaconMajorValue(0)
    var minorValue = CLBeaconMinorValue(1)
    var url = URL(string: "http://www.njc.co.jp")
    
    var indicator: UIActivityIndicatorView!
    
    var titleString: String = ""
    var noticeflg: Int = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ud.set("http://www.njc.co.jp", forKey: "url")
        
        let deviceId = UIDevice.current.identifierForVendor!.uuidString
        ud.set(deviceId, forKey: "deviceId")
        
        // Indicatorのインスタンスを作成
        indicator = UIActivityIndicatorView()
        // 画面の中央に表示するようにframeを変更する
        let w = CGFloat(indicator.frame.size.width)
        let h = CGFloat(indicator.frame.size.height)
        let x = self.view.frame.size.width/2 - w/2
        let y = self.view.frame.size.height/2 - w/2
        indicator.frame = CGRect(x: x, y: y, width: w, height: h)
        indicator.center = self.view.center
        
        indicator.hidesWhenStopped = true
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        
        // サブビューに追加する
        self.view.addSubview(indicator)
        
        
        // ロケーションマネージャの作成
        locationManager = CLLocationManager()
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = CLActivityType.fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // 位置情報使用確認のステータスを取得
        let locationStatus = CLLocationManager.authorizationStatus()
        
        if locationStatus == CLAuthorizationStatus.notDetermined {
            print("CLAuthorizedStatus: \(locationStatus)")
            
            // 位置情報使用確認ダイアログを表示
            locationManager.requestAlwaysAuthorization()
        }
        
        if ud.object(forKey: "email") != nil {
            loadState()
            
            if authorization == nil {
                authOID()
            } else {
                service.authorizer = authorization
                serviceCal.authorizer = authorization
            }
        } else {
            authOID()
        }
        
        getCalStatusField.delegate = self
        
        // 画面を更新してリージョン検知開始
        tableReload()
        
    }
    
    //
    // GTMAppAuth系
    //
    
    func authOID() {
        let issuer = URL(string: kIssuer)
        let redirectURI = URL(string: kRedirectURI)
        
        // discovers endpoints
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer!, completion: {
            (configuration, error) in
            if configuration == nil {
                print("Error retrieving discovery document: \(error?.localizedDescription)")
                self.setGtmAuthorization(stauthorization: nil)
                return
            }
            
            print("Got configuration: \(configuration!)")
            
            // builds authentication request
            let request: OIDAuthorizationRequest = OIDAuthorizationRequest.init(
                configuration: configuration!,
                clientId: self.kClientID,
                scopes: self.scopes,
                redirectURL: redirectURI!,
                responseType: OIDResponseTypeCode,
                additionalParameters: nil)
            
            // performs authentication request
            let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
            print("Initiating authorization request with scope: \(request.scope!)")
            
            appDelegate.currentAuthorizationFlow = OIDAuthState.authState(
                byPresenting: request,
                presenting: self,
                callback: {
                    (authState, error) in
                    if authState != nil {
                        let gauthorization: GTMAppAuthFetcherAuthorization = GTMAppAuthFetcherAuthorization(authState: authState!)
                        self.setGtmAuthorization(stauthorization: gauthorization)
                        
                        if let authIdt = authState?.lastTokenResponse?.idToken {
                            do {
                                let jwt = try decode(jwt: String(authIdt))
                                let emailStr = jwt.body["email"] as! String
                                self.ud.set(emailStr, forKey: "email")
                                print(emailStr)
                            } catch {
                                // error
                            }
                        }
                        print("Got authorization tokens. Access token: \(authState?.lastTokenResponse?.accessToken)")
                    } else {
                        self.setGtmAuthorization(stauthorization: nil)
                        print("Authorization error: \(error?.localizedDescription)")
                    }
            })
        })
    }
    
    func saveState() {
        if authorization != nil {
            if (authorization?.canAuthorize())! {
                GTMAppAuthFetcherAuthorization.save(authorization!, toKeychainForName: "authorization")
            } else {
                GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: "authorization")
            }
        } else {
            GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: "authorization")
        }
    }
    
    func loadState() {
        if GTMAppAuthFetcherAuthorization(fromKeychainForName: "authorization") != nil {
            let lauthorization: GTMAppAuthFetcherAuthorization = GTMAppAuthFetcherAuthorization(fromKeychainForName: "authorization")!
            self.setGtmAuthorization(stauthorization: lauthorization)
        }
    }
    
    func setGtmAuthorization(stauthorization: GTMAppAuthFetcherAuthorization?) {
        if authorization == stauthorization {
            return
        }
        authorization = stauthorization
        stateChanged()
        service.authorizer = authorization
        serviceCal.authorizer = authorization
    }
    
    func stateChanged() {
        self.saveState()
    }
    
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (UIAlertAction) -> Void in
            print("Tap Cancel")
        })
        let okAction = UIAlertAction(title: "OK", style: .default, handler:{ (UIAlertAction) -> Void in
            print("Tap OK")
        })
        
        alert.addAction(cancelAction)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    //
    // スプレッドシートデータ
    //
    
    // beacon情報を取得
    func callAppsScript() {
        let baseUrl = "https://script.googleapis.com/v1/scripts/\(kScriptID):run"
        let durl = GTLUtilities.url(with: baseUrl, queryParameters: nil)
        
        let request = GTLObject()
        request.setJSONValue("getSpreadData", forKey: "function")
        print(request.json)
        
        service.fetchObject(byInserting: request, for: durl!, delegate: self, didFinish: #selector(ViewController.setResultWithTicket(ticket:finishedWithObject:error:)))
    }
    
    func setResultWithTicket(ticket: GTLServiceTicket, finishedWithObject object: GTLObject, error: NSError?) {
        
        if let error = error {
            showAlert(title: "The API returned the error: ", message: error.localizedDescription)
            return
        }
        
        if let apiError = object.json["error"] as? [String: AnyObject] {
            let details = apiError["details"] as! [[String: AnyObject]]
            var errMessage = String(
                format: "Script error message: %@\n",
                details[0]["errorMessage"] as! String
            )
            
            if let stacktrace = details[0]["scriptStackTraceElements"] as? [[String: AnyObject]]{
                for trace in stacktrace {
                    let f = trace["function"] as? String ?? "Unknown"
                    let num = trace["lineNumber"] as? Int ?? -1
                    errMessage += "\t\(f): \(num)\n"
                }
            }
            
            print(errMessage)
            
        } else {
            // 変数を初期化
            var getBeaconList = [NSDictionary]()
            var getBeaconUUID = Array<String>()
            
            let response = object.json["response"] as! [String: AnyObject]
            
            let gresult = response["result"]
            let gdatas = gresult!["data"] as! NSMutableArray
            
            for gdata in gdatas {
                let gdataArray = gdata as! NSDictionary
                let gdataUuid = String(describing: gdataArray["UUID"]!)
                let gdataMajor = String(describing: gdataArray["Major"]!)
                let gdataMinor = String(describing: gdataArray["Minor"]!)
                let gdataRoom = String(describing: gdataArray["Room"]!)
                
                let gdataBcn: NSDictionary = ["uuid": gdataUuid, "major": gdataMajor, "minor": gdataMinor, "room": gdataRoom]
                
                getBeaconList.append(gdataBcn)
            }
            
//            print(getBeaconList)
            print("-------")
            
            ud.set(getBeaconList, forKey: "beaconList")
            
            for getBeacon in getBeaconList {
                getBeaconUUID.append(getBeacon["uuid"] as! String)
            }
            
            let orderedSet = NSOrderedSet(array: getBeaconUUID)
            let beaconOrderedUUID = orderedSet.array as! Array<String>
            ud.set(beaconOrderedUUID, forKey: "beaconUUID")
            print(beaconOrderedUUID)
            print("-------")
            ud.synchronize()
        }
        
        tableReload()
        
        indicator.stopAnimating()
        importBtn.isEnabled = true
    }
    
    // beacon通知情報をチェック・記録
    func callCheckScript(roomId: String, startTime: GTLDateTime, eid: String) {
        let baseUrl = "https://script.googleapis.com/v1/scripts/\(kScriptID):run"
        let durl = GTLUtilities.url(with: baseUrl, queryParameters: nil)
        
        var did = ""
        var uid = ""
        
        let request = GTLObject()
        if let deviceId = ud.object(forKey: "deviceId") {
            did = deviceId as! String
        } else {
            uid = "unknown"
        }
        if let email = ud.object(forKey: "email") {
            uid = email as! String
        } else {
            uid = "unknown"
        }
        let confdate = "\(startTime.dateComponents.year!)-\(startTime.dateComponents.month!)-\(startTime.dateComponents.day!)"
        var confstart = ""
        if startTime.dateComponents.minute! < 10 {
            confstart = "\(startTime.dateComponents.hour!):0\(startTime.dateComponents.minute!)"
        } else {
            confstart = "\(startTime.dateComponents.hour!):\(startTime.dateComponents.minute!)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let createdDate = formatter.string(from: Date())
        let param = ["deviceid":did, "id":uid, "rid":roomId, "status":"in", "confdate":confdate, "confstart":confstart, "updatetime":createdDate, "eventid": eid]
        request.setJSONValue("checkSpreadData", forKey: "function")
        request.setJSONValue(param, forKey: "parameters")
//        print(request.json)
        
        service.fetchObject(byInserting: request, for: durl!, delegate: self, didFinish: #selector(ViewController.setCheckWithTicket(ticket:finishedWithObject:error:)))
    }
    
    func setCheckWithTicket(ticket: GTLServiceTicket, finishedWithObject object: GTLObject, error: NSError?) {
        
        if let error = error {
            showAlert(title: "The API returned the error: ", message: error.localizedDescription)
            return
        }
        
        if let apiError = object.json["error"] as? [String: AnyObject] {
            let details = apiError["details"] as! [[String: AnyObject]]
            var errMessage = String(
                format: "Script error message: %@\n",
                details[0]["errorMessage"] as! String
            )
            
            if let stacktrace = details[0]["scriptStackTraceElements"] as? [[String: AnyObject]]{
                for trace in stacktrace {
                    let f = trace["function"] as? String ?? "Unknown"
                    let num = trace["lineNumber"] as? Int ?? -1
                    errMessage += "\t\(f): \(num)\n"
                }
            }
            
            print(errMessage)
            
        } else {
            let response = object.json["response"] as! [String: AnyObject]
            let lresult: Int = response["result"] as! Int? ?? 0
            print("noticeflg = \(lresult)")
            
            noticeflg = lresult
            
            if noticeflg == 1 {
                // 通知を発行
                sendNotificationWithMessage(message: "\(titleString)")
            }
        }
    }
    
    
    //
    // 画面表示とリージョン検知開始
    //
    
    func tableReload() {
        beaconList = [NSDictionary]()
        if let beaconArray = ud.object(forKey: "beaconList") {
            for data in beaconArray as! [NSDictionary] {
                beaconList.append(data)
            }
        }
        
        if let getMinute: Int = ud.object(forKey: "getminute") as! Int? {
            getCalStatusField.text = String(getMinute)
        } else {
            getCalStatusField.text = "30"
            ud.set(30, forKey: "getminute")
        }
        
        print("relooooad")
        
        tableView.reloadData()
        
        beaconUUID = Array<String>()
        if let beaconSearch = ud.object(forKey: "beaconUUID") {
            for data in beaconSearch as! Array<String> {
                beaconUUID.append(data)
            }
        }
        
        beaconRegionArray = [CLBeaconRegion]()
        
        for i in 0 ..< beaconUUID.count {
            let uuid: UUID = UUID(uuidString: "\(String(describing: beaconUUID[i]).lowercased())")!
            
            // リージョン検知のインスタンスを作成
            beaconRegion = CLBeaconRegion(proximityUUID: uuid, identifier: "beacon\(i)")
            
            beaconRegionArray.append(beaconRegion)
            
            // リージョン検知開始
            locationManager.startMonitoring(for: beaconRegion)
        }
        
    }
    
    //
    // LocationManager
    //
    
    // LocationManagerがモニタリングを開始したというイベントを受け取る
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        // 既にRegion内に入っているビーコンの問い合わせ
        self.locationManager.requestState(for: region)
    }
    
    // 現在リージョン内にいるかどうかの通知を受け取る
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        switch (state) {
        case .inside:
            print("CLRegionStateInside: \(region.identifier)")
            
            self.locationManager.startRangingBeacons(in: region as! CLBeaconRegion)
            
        case .outside:
            print("CLRegionStateOutside: \(region.identifier)")
        case .unknown:
            print("CLRegionStateUnknown: \(region.identifier)")
        }
    }
    
    // リージョン内に入ったというイベントを受け取る
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("didEnterRegion")
    }
    
    // レンジングを行ったというイベントを受け取る
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if beacons.count == 0 { return }
        
        var bcnDictionary: NSDictionary = NSDictionary()
        let bcnArray: NSMutableArray = NSMutableArray()
        
        print(beacons.count)
        
        for beacon in beacons {
            if beacon.rssi != 0 {
                print(region.proximityUUID)
                bcnDictionary = ["uid":region.proximityUUID, "major":beacon.major, "minor":beacon.minor, "rssi":beacon.rssi]
                bcnArray.add(bcnDictionary)
            }
        }
        
        if bcnArray.count != 0 {
            
            var bcnRssi: Int = -100
            var bcnUUID = UUID()
            var bcnMajor: NSNumber = 0
            var bcnMinor: NSNumber = 0
            
            for i in 0 ..< bcnArray.count {
                let bcnAct: NSDictionary = bcnArray[i] as! NSDictionary
                if bcnRssi < bcnAct["rssi"] as! Int {
                    bcnRssi = bcnAct["rssi"] as! Int
                    bcnUUID = bcnAct["uid"] as! UUID
                    bcnMajor = bcnAct["major"] as! NSNumber
                    bcnMinor = bcnAct["minor"] as! NSNumber
                }
            }
            
            print("◇◇◇◇◇◇◇◇◇◇")
            
            regionId = ""
            
            regionId = compareGetId(uuid: bcnUUID, major: bcnMajor, minor: bcnMinor).lowercased()
            
            if regionId != "" {
                // カレンダーイベント確認開始
                fetchEvents()
            }
            
            self.locationManager.stopRangingBeacons(in: region)
            
        }
    }
    
    func compareGetId(uuid: UUID, major: NSNumber, minor: NSNumber) -> String {
        var getId = ""
        
        for data in beaconList {
            if String(describing: uuid) == data["uuid"] as! String {
                if String(describing: major) == data["major"] as! String {
                    if String(describing: minor) == data["minor"] as! String {
                        getId = data["room"] as! String
                    }
                }
            }
        }
        
        return getId
    }
    
    // リージョンから出たというイベントを受け取る
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("didExitRegion")
        //        sendNotificationWithMessage(message: String(describing: region))
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("monitoringDidFailForRegion \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error)")
    }
    
    //
    // カレンダー処理
    //
    func fetchEvents() {
        let calendar = NSCalendar.current
        
        // 範囲0だとなにもカレンダーイベントを取得しないので回避
        var nflg = 0
        
        var compBefore = DateComponents()
        var compAfter = DateComponents()
        
        if let getMinute: Int = ud.object(forKey: "getminute") as! Int? {
            if getMinute != 0 {
                // mod:後のみ
//                compBefore.minute = -getMinute
                compBefore.minute = 0
                compAfter.minute = getMinute
                nflg = 1
            }
        }
        
        if nflg == 0 {
            compAfter.minute = 1
        }
        
        let dMin = calendar.date(byAdding: compBefore, to: Date())
        let dMax = calendar.date(byAdding: compAfter, to: Date())
        let query = GTLQueryCalendar.queryForEventsList(withCalendarId: "primary")
        
        // 検索条件：最大取得件数
        query?.maxResults = 10
        // 検索条件：最小時間
        query?.timeMin = GTLDateTime(date: dMin, timeZone: NSTimeZone.local)
        // 検索条件：最大時間
        query?.timeMax = GTLDateTime(date: dMax, timeZone: NSTimeZone.local)
        
        query?.singleEvents = true
        
        // 検索条件：結果表示順
        // mod:後の予定優先
        query?.orderBy = kGTLCalendarOrderByStartTime
//        query?.orderBy =
        
        serviceCal.executeQuery(
            query!,
            delegate: self,
            didFinish: #selector(displayResultWithTicket(ticket:finishedWithObject:error:))
        )
    }
    
    // カレンダー情報表示処理
    func displayResultWithTicket(ticket: GTLServiceTicket, finishedWithObject response: GTLCalendarEvents, error: NSError?) {
        if let error = error {
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }
        
//        var titleString = ""
        var eventString = ""
        var attachString = ""
        var eidString = ""
        var startTime = GTLDateTime()
        
        
        
        let roomId: String = regionId
        print(roomId)
        print(ud.object(forKey: "email") ?? "unknown")
        
        // カレンダーイベント取得
        if let events = response.items() , !events.isEmpty {
            for event in events as! [GTLCalendarEvent] {
                if event.start.dateTime != nil {
                    startTime = event.start.dateTime
                    if event.descriptionProperty != nil {
                        // カレンダーイベント説明項目（descriptionProperty）からRoom情報が一致するか判断
                        if event.descriptionProperty.lowercased().range(of: roomId) != nil {
                            // 説明項目取得
                            eventString = "\(event.descriptionProperty)"
                            //                        print("a = \(eventString)")
                            // タイトル項目（summary）取得
                            if event.summary != nil {
                                titleString = "\(event.summary!)"
                            }
                            // 添付ファイル項目（attachments）取得
                            if event.attachments != nil {
                                attachString = "\(event.attachments)"
                            }
                            if event.htmlLink != nil {
                                let eidStart = String(event.htmlLink)?.range(of: "eid=")?.upperBound
                                if eidStart != nil {
                                    eidString = String(event.htmlLink.substring(from: eidStart!))
                                    print(eidString)
                                        
                                    // UserDefaultsに格納してあるURLスキームを上書き
                                    ud.set(eidString, forKey: "eid")
                                }
                            }
                        }
                    }
                }
                print(event.location)
                
            }
        } else {
            print("No upcoming events found.")
        }
        
        // 条件によりURL取得方法分岐
        
        // 説明項目に値があるか
        if eventString != "" {
            // 説明項目に”[https://”から”]”に囲まれた値があるか
            let folderStart = String(eventString)?.range(of: "[https://")?.lowerBound
            if folderStart != nil {
                let urlEnd = String(eventString.substring(from: folderStart!))?.range(of: "]")?.upperBound
                
                if urlEnd != nil {
                    let urlLength = String(eventString.substring(from: folderStart!))?.substring(to: urlEnd!).characters.count
                    let folderEnd = String(eventString)?.index(folderStart!, offsetBy: urlLength!)
                    
                    //                    print("folder \(folderStart) - \(folderEnd)")
                    
                    let urlFolder = String(eventString)[folderStart!..<folderEnd!]
                    
                    // 通知からGoogleファイルを開くためのURLスキームを作成
                    let folderString = "googledrive://" + urlFolder
                    print(folderString)
                    
                    // UserDefaultsに格納してあるURLスキームを上書き
                    ud.set(folderString, forKey: "url")
                    
                    // 同じ予定の通知を出していないかチェック
                    callCheckScript(roomId: roomId, startTime: startTime, eid: eidString)
                }
            } else {
                // 添付ファイル項目に値があるか
                if attachString != "" {
                    //                    print(attachString)
                    if attachString.lowercased().contains("docs.google.com") {
                        // 添付ファイル項目の”docs.google.com/”から”?”に囲まれた値を取得
                        let fileStart = String(attachString)?.range(of: "docs.google.com")?.lowerBound
                        let fileEnd = String(attachString)?.range(of: "?")?.upperBound
                        //                        print("Region \(fileStart) - \(fileEnd)")
                        
                        let urlFile = String(attachString)[fileStart!..<fileEnd!]
                        
                        // 通知からGoogleファイルを開くためのURLスキームを作成
                        let fileString = "googledrive://docs.google.com/" + urlFile
                        print(fileString)
                        // UserDefaultsに格納してあるURLスキームを上書き
                        ud.set(fileString, forKey: "url")
                        
                        // 同じ予定の通知を出していないかチェック
                        callCheckScript(roomId: roomId, startTime: startTime, eid: eidString)
                    } else if attachString.lowercased().contains("drive.google.com") {
                        // 添付ファイル項目の”docs.google.com/”から”?”に囲まれた値を取得
                        let fileStart = String(attachString)?.range(of: "drive.google.com")?.lowerBound
                        let fileEnd = String(attachString)?.range(of: "?")?.upperBound
                        //                        print("Region \(fileStart) - \(fileEnd)")
                        
                        let urlFile = String(attachString)[fileStart!..<fileEnd!]
                        
                        // 通知からGoogleファイルを開くためのURLスキームを作成
                        let fileString = "googledrive://drive.google.com/" + urlFile
                        print(fileString)
                        // UserDefaultsに格納してあるURLスキームを上書き
                        ud.set(fileString, forKey: "url")
                        
                        // 同じ予定の通知を出していないかチェック
                        callCheckScript(roomId: roomId, startTime: startTime, eid: eidString)
                    }
                }
            }
        }
        
    }
    
    //
    // ローカル通知
    //
    
    // ローカル通知の設定・発行
    func sendNotificationWithMessage(message: String) {
        if #available(iOS 10.0, *) {
            let absent = UNNotificationAction(identifier: ActionIdentifier.absent.rawValue, title: "キャンセル", options: [])
            
            let category = UNNotificationCategory(identifier: "message", actions: [absent], intentIdentifiers: [], options: [])
            UNUserNotificationCenter.current().setNotificationCategories([category])
            
            let content = UNMutableNotificationContent()
            content.title = message
            content.body = "会議の資料を開きます"
            content.sound = UNNotificationSound.default()
            
            content.categoryIdentifier = "message"
            
            let request = UNNotificationRequest(identifier: message, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        } else {
            let notification: UILocalNotification = UILocalNotification()
            notification.alertBody = message
            notification.soundName = UILocalNotificationDefaultSoundName
            
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }
    
    
    //
    // UI系
    //
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beaconList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: "Cell")
        
        cell.textLabel?.text = beaconList[indexPath.row]["room"] as? String
        cell.detailTextLabel?.text = "\(beaconList[indexPath.row]["major"] as! String) : \(beaconList[indexPath.row]["minor"] as! String)"
        return cell
    }
    
    //
    @IBAction func tapView(_ sender: UITapGestureRecognizer) {
        // 画面タップでキーボードを下げる
        self.view.endEditing(true)
        
        // selecttableviewと同じ動作
        let touch = sender.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: touch) {
            let alertController = UIAlertController(title: "削除確認", message: "\(indexPath.row + 1)行目を削除します。よろしいですか?", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "はい", style: .default, handler: {(action:UIAlertAction!) -> Void in
                self.beaconList.remove(at: indexPath.row)
                self.ud.set(self.beaconList, forKey: "beaconList")
                
                var getBeaconUUID = Array<String>()
                
                for beacon in self.beaconList {
                    getBeaconUUID.append(beacon["uuid"] as! String)
                }
                
                let orderedSet = NSOrderedSet(array: getBeaconUUID)
                let beaconOrderedUUID = orderedSet.array as! Array<String>
                self.ud.set(beaconOrderedUUID, forKey: "beaconUUID")
                print(beaconOrderedUUID)
                print("-------")
                
                self.ud.synchronize()
                
                if self.beaconRegionArray.count > 0 {
                    for region in self.beaconRegionArray {
                        // レンジングを停止
                        self.locationManager.stopMonitoring(for: region)
                    }
                }
                print("StopMonitor!!")
                
                self.tableReload()
            })
            let cancelAction = UIAlertAction(title: "いいえ", style: .default, handler: {(action: UIAlertAction!) -> Void in
            })
            
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    //
    func textFieldDidEndEditing(_ textField: UITextField) {
        if getCalStatusField.text == "" {
            getCalStatusField.text = "0"
        }
        
        ud.set(Int(getCalStatusField.text!), forKey: "getminute")
        print(getCalStatusField.text!)
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func tapImport(_ sender: UIButton) {
        importBtn.isEnabled = false
        // クルクルと回し始める
        indicator.startAnimating()
        
        print(beaconRegionArray.count)
        if beaconRegionArray.count > 0 {
            for region in beaconRegionArray {
                // リージョン検知を停止
                locationManager.stopMonitoring(for: region)
            }
        }
        
        print("StopMonitor!!")
        callAppsScript()
        
    }
    
}
