//
//  YKMainViewControl.swift
//  iOSYunkuSDK
//
//  Created by Brandon on 15/6/25.
//  Copyright (c) 2015年 goukuai. All rights reserved.
//

import UIKit
import YunkuSwiftSDK
import AssetsLibrary

public class YKMainViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,FileListDataDelegate,UIActionSheetDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate,RenameDelegate,NewFolderDelegate,FileItemOperateDelegate,RequestDelegate,UIAlertViewDelegate,FileUploadManagerDelegate{
    
    //=================view=================
    var tableView:UITableView!
    var refreshControl:UIRefreshControl!
    var emptyLabel:UILabel!
 
    //======================================
    
    
    //================ data =================
    var fullPath = SDKConfig.orgRootPath
    var fileList:Array<FileData>!
    var photoArray:Array<ImageData>!
    
    var isAnimating = false
    var dropDownViewIsDisplayed = false
    
    var hightLightFileName = ""
    
    var isLoading = false
    
    public var option:Option!
    
    public var delegate:HookDelegate!

    //======================================
  
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.whiteColor()
        
        if self == self.navigationController?.viewControllers[0] as! UIViewController{//is root
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSBundle.getLocalStringFromBundle("Close", comment: ""),
                style: UIBarButtonItemStyle.Plain, target: self, action:"onClose:")
        }
        
        //设置返回按钮的文字
        var backButton = UIBarButtonItem(title: NSBundle.getLocalStringFromBundle("Back", comment: ""),
                        style: UIBarButtonItemStyle.Plain, target: self, action:"onBack:")
        
        self.navigationItem.backBarButtonItem = backButton
        
        
        if !(option == nil || !option.canUpload){
            //设置添加按钮
            var addButton = UIBarButtonItem(title: NSBundle.getLocalStringFromBundle("Add", comment: ""),
                style: UIBarButtonItemStyle.Plain, target: self, action:"onAdd:")
            self.navigationItem.rightBarButtonItem = addButton
        }
        
        //设置标题
        self.navigationItem.title = FileDataManager.sharedInstance!.isRootPath(self.fullPath) ? SDKConfig.orgRootTitle : self.fullPath.lastPathComponent
        
        self.tableView = UITableView(frame: self.clientRect(), style: UITableViewStyle.Plain)
        self.tableView.backgroundColor = UIColor.clearColor()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.view.addSubview(self.tableView)
        
        //添加下拉刷新的控件
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl.addTarget(self, action: "onRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refreshControl)
      
        //设置emptyView
        self.emptyLabel = UILabel(frame: CGRectMake(0, 0, self.tableView.frame.width, 300))
        self.emptyLabel.text = NSBundle.getLocalStringFromBundle("Empty Folder", comment: "")
        self.emptyLabel.textAlignment = NSTextAlignment.Center
        self.emptyLabel.textColor = UIColor.grayColor()
        self.emptyLabel.font = UIFont.systemFontOfSize(14)
        self.emptyLabel.hidden = false
        
        self.tableView.addSubview(self.emptyLabel)
        
        self.initData()
        
        FileDataManager.sharedInstance?.registerHook(self.delegate)
        
    }
    
    //MARK:文件列表返回和文件
    func onBack(sender:AnyObject?){
        if FileDataManager.sharedInstance!.isRootPath(self.fullPath) {
            self.dismissViewControllerAnimated(true, completion: nil)
            
        }else{
            self.navigationController?.popToRootViewControllerAnimated(true)
        }
    
    }
    
    //MARK:列表刷新
    func onRefresh(sender:AnyObject?){
        self.initData()
    }
    
    //MARK:文件添加
    func onAdd(sender:AnyObject?){
        
        var sheet = UIActionSheet(title: NSBundle.getLocalStringFromBundle("Add files to ...", comment: ""), delegate: self, cancelButtonTitle: NSBundle.getLocalStringFromBundle("Cancel", comment: ""),
            destructiveButtonTitle: nil, otherButtonTitles:  NSBundle.getLocalStringFromBundle("New Folder", comment: ""),
            NSBundle.getLocalStringFromBundle("Gallery", comment: ""), NSBundle.getLocalStringFromBundle("Take Photo", comment: ""),
            NSBundle.getLocalStringFromBundle("Gknote", comment: ""))
        sheet.tag = actionSheetTagAddFile
        sheet.showInView(self.view)
        
       
    }
    
    
    //MARK:初始化列表数据
    func initData(){
        self.emptyLabel.text = NSBundle.getLocalStringFromBundle("Loading", comment: "")
        
        FileDataManager.sharedInstance?.getFileList(0, fullPath: fullPath, delegate: self)
    }
    
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.fileList == nil || self.fileList.count == 0 {
            self.emptyLabel.hidden = false
            return 0
        }
        self.emptyLabel.hidden = true
        return self.fileList.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell =  FileListCell()
        cell.tag = indexPath.row
        cell.bindView( fileList[indexPath.row], delegate:self, option: self.option)
        return cell
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 54
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
   
        var data = fileList[indexPath.row]
        
        //文件夹
        if data.dir == FileData.dirs {
            
            var control = YKMainViewController()
            control.fullPath = data.fullPath
            control.delegate = self.delegate
            control.option = self.option
            self.navigationController?.pushViewController(control, animated: true)
        
        }else if data.isFoot{
            if !self.isLoading{
                var cell: FileListCell = tableView.cellForRowAtIndexPath(indexPath) as! FileListCell
                cell.moreLabel.text = NSBundle.getLocalStringFromBundle("Loading", comment: "")
                self.isLoading = true
                FileDataManager.sharedInstance?.getMoreList(self)
            }
           
        }else {
            //打开文件
            if Utils.isImageType(data.fileName){
                var photoControl =  FGalleryViewController(photoSource: self, barItems: nil)
                var imageList = Array<ImageData>()
                var index = 0
                var startIndex = 0 //当前文件在图库中的位置
                for fileData in self.fileList{
                    if Utils.isImageType(fileData.fileName){
                        imageList.append(ImageData(data:fileData))
                        //当前列表
                        if data.fullPath == fileData.fullPath{
                            startIndex = index
                        }
                        
                        index++
                    }
                }
                
                self.photoArray = imageList
                photoControl.startingIndex = startIndex
                photoControl.photoArray = NSMutableArray(array: self.photoArray)
                self.presentViewController(UINavigationController(rootViewController: photoControl), animated: true, completion: nil)

            } else {
                
                var fileViewer = FileViewController(fullpath: data.fullPath, filename: data.fileName, dir: data.dir, filehash: data.fileHash, localpath: "", filesize: data.fileSize)
                fileViewer.uploadDelegate = self
                self.navigationController?.pushViewController(fileViewer, animated: true)
            }
            
        }
        
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.

        self.tableView = nil
        self.refreshControl = nil
        self.emptyLabel = nil
    }
    
    
    //MARK:接收到文件请求数据
    func onHttpRequest(start: Int, fullPath: String, list: Array<FileData>) {
        self.refreshControl.endRefreshing()
        
        self.isLoading = false
        
        self.emptyLabel.text = NSBundle.getLocalStringFromBundle("Empty Folder", comment: "")
        
        //防止多次点击，返回错位的列表
        if self.fullPath == fullPath{
            
            if start == 0{
                self.fileList = list
            }else{
                //=====如果最后一个是 加载更多一项，要移除=====
                var footer = self.fileList.last!
                if footer.isFoot{
                    self.fileList.removeLast()
                }
                //===================================
            
                self.fileList.extend(list)
            }
            
            if list.count >= FileDataManager.pageSize {//大于是防止服务端错误
                //还有更多数据添加更多一项
                var footer = self.fileList.last!
                if !footer.isFoot {
                    self.fileList.append(FileData.createFooter())
                }
                
            }

            self.tableView.reloadData()
        }
        
        if !self.hightLightFileName.isEmpty{
            DialogUtils.hideProgresing(self)
            self.hightLightName(self.hightLightFileName)
        
        }
  
    }
    
    func onHttpRequest(action: Action) {
        
        switch action {
        case Action.Delete:
            DialogUtils.hideProgresing(self)
            
            self.fileList.removeAtIndex(self.operatingIndex)
            self.tableView.reloadData()
            
        default:
            ()
        }

    }
    
    //MARK:返回请求错误信息
    func onError(errorMsg:String){
        self.isLoading = false
        if self.refreshControl.refreshing {
            self.refreshControl.endRefreshing()
        }
        
        self.view.makeToast(message: errorMsg)
        self.emptyLabel.text = errorMsg
        
    }
    
    //MARK:返回Hook错误
    func onHookError(type:HookType){
        self.isLoading = false
        if self.refreshControl.refreshing {
            self.refreshControl.endRefreshing()
        }
        DialogUtils.hideProgresing(self)
        
    }
    
    //MARK:没有网络
    func onNetUnable(){
        self.isLoading = false
        if self.refreshControl.refreshing {
            self.refreshControl.endRefreshing()
        }
        var message = NSLocalizedString("Network not available", tableName: nil, bundle: NSBundle.myResourceBundleInstance!, value: "", comment: "")
        self.view.makeToast(message: message)
        self.emptyLabel.text = message
        DialogUtils.hideProgresing(self)
        
    }
    
    let actionSheetTagAddFile = 1
    let actionSheetTagFileOpration = 2
    
    public func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        if actionSheet.tag == actionSheetTagAddFile {
            switch buttonIndex {
            case 1://Folder
                var newFolderC = NewFolderController()
                newFolderC.list = fileList
                newFolderC.upFullPath = self.fullPath
                newFolderC.delegate = self
                var navC = UINavigationController(rootViewController: newFolderC)
                self.presentViewController(navC, animated: true, completion: nil)
                
            case 2://Gallery
                
                if(!Utils.canAccessPhotos()){
                    var message = NSBundle.getLocalStringFromBundle("Need the prermission of Photos , please access the Setting -> Private -> Photos", comment: "")
                    var alert = UIAlertView(title: nil, message: message, delegate: self, cancelButtonTitle: NSBundle.getLocalStringFromBundle("I Know", comment: ""))
                    alert.show()
                    return
                    
                }
                
                if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary){
                    
                    var picker = UIImagePickerController()
                    picker.delegate = self
                    picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
                    self.presentViewController(picker, animated: true, completion: nil)

                }
                
            case 3://Photos
                if(!Utils.canAcessCamera()){
                    var message = NSBundle.getLocalStringFromBundle("Need the prermission of Photos , please access the Setting -> Private -> Camera", comment: "")
                    var alert = UIAlertView(title: nil, message: message, delegate: self, cancelButtonTitle: NSBundle.getLocalStringFromBundle("I Know", comment: ""))
                    alert.show()
                    return
                    
                }
                
                if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera){
                    var picker = UIImagePickerController()
                    picker.delegate = self
                    picker.sourceType = UIImagePickerControllerSourceType.Camera
                    self.presentViewController(picker, animated: true, completion: nil)
                }
                
            case 4://gknote
                
                var control = GKnoteViewController()
                control.fileList = self.fileList
                control.requestPath = self.fullPath
                control.delegate = self
                var navC = UINavigationController(rootViewController: control)
               
                self.presentViewController(navC, animated: true, completion: nil)

            default:
                ()
                
            }

        }else if actionSheet.tag == actionSheetTagFileOpration {
            
            let reNameIndex = option.canRename ? 1 : -1
            
            let deleteIndex = option.canRename ? 2 : 1
            
            switch buttonIndex {
                
            case reNameIndex:
                
                var renameC = RenameController()
                renameC.list = fileList
                renameC.delegate = self
                renameC.fileIndex = self.operatingIndex
                var navC = UINavigationController(rootViewController: renameC)
                self.presentViewController(navC, animated: true, completion: nil)
                
            case deleteIndex:
                
                var message = NSBundle.getLocalStringFromBundle("Are you sure to delete this file?", comment: "")
                DialogUtils.showTipDialog(message, okBtnString: NSBundle.getLocalStringFromBundle("Delete", comment: ""), delegate: self, tag: alertTagDelete)
                
            default:
                ()
                
            }

        }

    }

    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        
        var filename:String?
        var image: UIImage?
        
        if picker.sourceType == UIImagePickerControllerSourceType.Camera{
            image = info[UIImagePickerControllerOriginalImage] as? UIImage
            
           //根据当前时间生成照片的名字
            filename =  Utils.formatImageNameFromAssetLibrary(NSDate.new().timeIntervalSince1970)
            
            self.uploadImage(filename!, image: image!, picker: picker)
      
        }else if picker.sourceType == UIImagePickerControllerSourceType.PhotoLibrary{
            //获取照片在asset library的url
            var localUrl = info[UIImagePickerControllerReferenceURL] as? NSURL
            var loadError: NSError?
            
            let assetsLibrary = ALAssetsLibrary()
            assetsLibrary.assetForURL(localUrl, resultBlock: { (asset) -> Void in
                
                var imageRep:ALAssetRepresentation = asset.defaultRepresentation() as ALAssetRepresentation
                
                //获取照片的时间
                let date:NSDate = (asset?.valueForProperty(ALAssetPropertyDate) as! NSDate?)!
                
                //设置照片的名字
                filename =  Utils.formatImageNameFromAssetLibrary(date.timeIntervalSince1970)
                
                //获取照片的数据
                var iref: Unmanaged<CGImage> = imageRep.fullResolutionImage()
                image = UIImage( CGImage: iref.takeRetainedValue())
  
                self.uploadImage(filename!, image: image!, picker: picker)
                iref.retain()//避免被释放
 
                }, failureBlock: { (error) -> Void in
                    loadError = error;
            })
            
            
            if (loadError != nil) {
                LogPrint.error("image upload err:\(loadError)")
                
            }
        
        }

    }
   
    //MARK:上传图片
    func uploadImage(filename:String,image:UIImage,picker:UIImagePickerController){
        
        var localPath:String?
        let upFullPath = self.fullPath
        
        //保存至本地缓存
        localPath = Utils.saveImageToCache(image,fileName:filename)
        //设置上传路径
        var appendingString = upFullPath.isEmpty ? "": "/"
        var fullPath = String(format: "%@%@%@", upFullPath,appendingString,filename)
        
        LogPrint.info("fileName:\(filename)")
        LogPrint.info("localPath:\(localPath)")
        
        picker.dismissViewControllerAnimated(true, completion: {()-> Void in
            
            FileUploadManager.sharedInstance?.upload(fullPath, data: LocalFileData(fileName: filename, localPath: localPath!),view:self.view)
            FileUploadManager.sharedInstance?.delegate = self
            
        })
        
    }
  
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK:接受需要高亮显示的文件名
    func hightLightName(hightLightName: String) {
        
        for (index,data:FileData) in enumerate(self.fileList) {
            if data.fileName == hightLightName{
                self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Top)
                
                self.hightLightFileName = ""
            }
        }

    }
    
    //MARK:重命名操作完成
    func didRenamed(newName: String, index: Int) {
        var data = self.fileList[index]
        data.fileName = newName
        var parentPath = data.fullPath.stringByDeletingLastPathComponent
        var appendingString = parentPath.isEmpty ? "":"/"
        var newPath = "\(parentPath)\(appendingString)\(newName)"
        data.fullPath = newPath
        self.tableView.reloadData()
        self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: index, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Top)
    }
    
    //MARK:文件夹创建完成
    func didCreateFolder(fileName: String) {
        var data  = FileData()
        var appendingString = self.fullPath.isEmpty ? "":"/"
        data.fullPath = "\(self.fullPath)\(appendingString)\(fileName)"
        data.fileName = fileName
        data.dir = FileData.dirs
        data.lastDateline = Int(NSDate.new().timeIntervalSince1970)
        self.fileList.insert(data, atIndex: 0)
        self.tableView.reloadData()
        self.tableView.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.Top)
    }
    
    func onFileDidCreate(fileName: String) {
        self.hightLightFileName = fileName
        self.onRefresh(nil)
        DialogUtils.showProgresing(self)
    }
    
    //MARK:正在操作的一列index
    var operatingIndex:Int!
    
    //MARK:cell 单项操作
    func onItemOperte(index: Int) {
        
        self.operatingIndex = index
        
        var isSepecial = option != nil && ((option.canRename && !option.canDel) || (!option.canRename && option.canDel))
        
        var butonName =  isSepecial && option.canRename ? NSBundle.getLocalStringFromBundle("Rename", comment: "") : NSBundle.getLocalStringFromBundle("Delete", comment: "")
        
        var sheet = !isSepecial ? UIActionSheet(title: NSBundle.getLocalStringFromBundle("File Oprations...", comment: ""), delegate: self, cancelButtonTitle: NSBundle.getLocalStringFromBundle("Cancel", comment: ""),
            destructiveButtonTitle: nil, otherButtonTitles:  NSBundle.getLocalStringFromBundle("Rename", comment: ""),
            NSBundle.getLocalStringFromBundle("Delete", comment: ""))
            : UIActionSheet(title: NSBundle.getLocalStringFromBundle("File Oprations...", comment: ""), delegate: self, cancelButtonTitle: NSBundle.getLocalStringFromBundle("Cancel", comment: ""),
                destructiveButtonTitle: nil, otherButtonTitles: butonName)

        sheet.delegate = self
        sheet.tag = actionSheetTagFileOpration
        sheet.showInView(self.view)

    }
    
    //MARK:删除tag
    let alertTagDelete = 0
    
    public func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        
        if alertView.tag == alertTagDelete {
            if buttonIndex == 1 {
                
                var data = self.fileList[operatingIndex]
                self.view.makeToastActivity()
                
                FileDataManager.sharedInstance?.del(data.fullPath, delegate: self)
            }
        }
   
    }
    

    //MARK:兼容iPad bug
    public override func presentViewController(viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            
            NSOperationQueue.mainQueue().addOperationWithBlock{
                super.presentViewController(viewControllerToPresent, animated: flag, completion: completion)
            }
        
        }else{
            super.presentViewController(viewControllerToPresent, animated: flag, completion: completion)
        
        }
    }
    
    func onClose(sender:AnyObject){
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

