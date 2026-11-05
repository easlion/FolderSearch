# FolderSearch

FolderSearch V11 是以 Windows PowerShell 5.1 開發的檔案／資料夾名稱索引與快速搜尋工具，支援本機磁碟、可存取的映射網路磁碟、多磁碟搜尋及定時增量更新。

you can download it in D:\---> [FolderSearch.7z](./FolderSearch.7z)


本工具使用純文字索引檔（.index、.dirs、.meta.json），不需要 SQLite 或其他資料庫。搜尋對象是檔名與完整路徑，不是 Word、PDF 或其他檔案的內文。
1. 主要功能

|大功能                         |小功能                          |說明                                                 |

|----------------------------|-----------------------------|---------------------------------------------------|

|**索引建立（Full Build）**        |單一磁碟完整建置                     |掃描磁碟內的檔案與資料夾，建立名稱及路徑索引。                            |

|                            |平行目錄掃描                       |使用 Runspace Pool 處理目錄，預設最多 **32 個工作執行緒**。          |

|                            |補建缺少的索引                      |對尚未建立有效索引的磁碟執行 Full Build。                         |

|                            |進度／統計                        |顯示已索引項目、已處理目錄、待處理佇列、失敗數及速度。                        |

|**增量更新（Incremental Update）**|單一／全部磁碟更新                    |依既有目錄狀態偵測變化，不必每次重新列舉整棵目錄樹。                         |

|                            |平行變更檢查                       |比對目錄最後修改時間（UTC ticks），預設最多 **32 個工作執行緒**。          |

|                            |Fast Old Child Map           |從舊索引取得已變動目錄的直接子項目。                                 |

|                            |Delta 比對                     |辨識新增項目、移除項目及遭移除的資料夾子樹。                             |

|                            |Fast Rebuild + Count         |重建索引時同步計算檔案／資料夾數量，避免額外完整重算。                        |

|**快速搜尋（Search）**            |Search ONE / Search ALL      |搜尋單一磁碟或所有已有有效索引的磁碟；ALL 預設最多 **4 個平行工作執行緒**。        |

|                            |Name / Path                  |依檔案名稱或完整路徑比對。                                      |

|                            |Contains / StartsWith / Exact|支援包含、開頭符合與完全符合，不區分英文字母大小寫。                         |

|                            |即時結果                         |預設搜尋到結果就顯示；ALL 透過共用佇列集中輸出及統一編號。                    |

|                            |搜尋控制                         |`P` 暫停／恢復、`Q` 停止目前搜尋。                              |

|                            |結果操作                         |輸入編號開啟項目，或使用 `F<編號>` 在檔案總管定位。                      |

|**自動更新（Scheduler）**         |每日三次排程                       |透過 **Windows 工作排程器**在 **09:00、12:00、16:00** 啟動增量更新。|

|                            |防重複執行                        |工作排程 `IgnoreNew` 與 `AutoUpdate.lock` 避免自動更新程序重疊。   |

|                            |自動紀錄                         |記錄更新開始／結束、成功／失敗／略過及執行時間。                           |

|**資料與錯誤保護**                 |重試與失敗紀錄                      |針對目錄存取錯誤進行重試，將失敗資訊寫入 `.failed.log`。                |

|                            |暫存／備份／提交                     |使用 `.tmp`、`.bak` 檔案進行索引替換，失敗時嘗試恢復舊資料。              |

|                            |索引資訊                         |儲存檔案數、資料夾數、上次成功更新時間及處理速度等統計。                       |
> **增量偵測限制：**目前主要依賴目錄修改時間來判斷是否需要重新列舉。若檔案系統或 SMB 伺服器沒有如預期更新目錄時間，某些變更可能不會在增量更新時被偵測到；必要時應重新 Full Build。它不是即時檔案監控服務。
2. 系統需求

	●	Windows，具備 Windows PowerShell 5.1。

	●	可讀取欲建立索引的本機磁碟或網路磁碟。

	●	可寫入目前 Windows 使用者的 %LOCALAPPDATA%。

	●	若使用自動排程，必須可建立 Windows 工作排程工作。

	●	若企業原則要求 PowerShell 指令碼簽章，須遵守 IT 安全政策；-ExecutionPolicy Bypass 不能覆蓋強制的群組原則。
3. 檔案用途與儲存位置
3.1 GitHub 儲存庫

將本說明存放在儲存庫根目錄的 README.md（取代原先只有標題的內容）：

FolderSearch/                         ← GitHub repository root

├─ README.md                          ← 本文件

├─ FolderSearchV11.ps1                ← V11 主程式

├─ FolderSearchV11.bat                ← 本機啟動器

├─ FolderSearchV11- sever version.bat ← 網路路徑啟動器（選用）

├─ FolderSearchAutoUpdate.ps1         ← 自動增量更新

├─ InstallFolderSearchSchedule.ps1    ← 安裝每日排程

├─ FolderSearch.ps1                   ← 舊版（保留參考）

├─ FolderSearch v2.bat                ← 舊版啟動器

├─ FolderSearch v2 - sever version.bat← 舊版網路路徑啟動器

└─ FolderSearch.7z                    ← 壓縮封裝，非執行必需

本 README 以上傳壓縮檔內的 V11 四個執行檔為主要功能依據；舊版檔案僅作歷史版本區分。上述 Server 版 BAT 已另依 GitHub 儲存庫內容確認，其作用是從指定的映射磁碟路徑啟動腳本，不是共用索引伺服器。
3.2 本機部署（目前程式預設路徑）

將下列 4 個必要檔案放到 D:\Tools\，名稱保持不變：

D:\Tools\

├─ FolderSearchV11.ps1

├─ FolderSearchV11.bat

├─ FolderSearchAutoUpdate.ps1

├─ InstallFolderSearchSchedule.ps1

└─ Log\                             ← 自動更新程式會建立

   ├─ AutoUpdate.log                ← 執行紀錄

   ├─ AutoUpdate.log.old            ← 超過大小限制時產生的舊紀錄

   └─ AutoUpdate.lock               ← 避免自動更新重複執行
注意：目前原始碼使用 D:\Tools\Log\（Log 單數），不是 Logs。 AutoUpdate.lock 是鎖定檔，不是索引檔；執行期間不可隨意刪除。
3.3 索引資料夾（與程式所在位置分離）

每位 Windows 使用者的索引預設儲存在：

%LOCALAPPDATA%\FolderSearchV83\

├─ C.index

├─ C.dirs

├─ C.meta.json

├─ D.index

├─ D.dirs

├─ D.meta.json

├─ V.index

├─ V.dirs

├─ V.meta.json

├─ V.failed.log                   ← 發生目錄掃描錯誤時

├─ *.tmp                          ← 更新期間的暫存檔

└─ *.bak                          ← 更新期間的備份檔

以上為示例，只會有實際建立過索引的磁碟檔案；索引磁碟識別名稱由程式依磁碟根路徑產生。資料夾名稱保留 FolderSearchV83 是為了沿用歷史索引，不代表目前執行的是 V8.3。

|檔案類型           |內容／用途                                                  |

|---------------|-------------------------------------------------------|

|`*.index`      |一筆一行：`TYPE<TAB>NAME<TAB>FULLPATH`；`F` 為檔案、`D` 為資料夾。    |

|`*.dirs`       |一筆一行：`DIRECTORY_PATH<TAB>LastWriteTimeUtc.Ticks`，供增量檢查。|

|`*.meta.json`  |索引模式、項目數、最近成功更新時間、效能資料等。                               |

|`*.failed.log` |掃描／存取失敗資訊（非正常執行都會產生）。                                  |

|`*.tmp`／`*.bak`|更新階段的暫存及備份，供提交與失敗回復使用。                                 |
> **資料安全：**`.index` 會列出完整資料夾路徑與檔名，可能包含內部專案名稱或敏感資訊。不要將實際產出的索引、日誌、鎖定檔或憑證提交至公開 GitHub 儲存庫。
4. 快速開始
4.1 首次安裝與建立索引

	1.	將第 3.2 節的 4 個檔案複製到 D:\Tools\。

	2.	雙擊 D:\Tools\FolderSearchV11.bat，或使用 PowerShell 啟動：

powershell.exe -NoProfile -File "D:\Tools\FolderSearchV11.ps1"

BAT 目前另帶有 -ExecutionPolicy Bypass 參數；是否允許執行仍取決於該電腦的安全原則。

	3.	在主選單選擇 D（對指定磁碟 Full Build）或 E（補建所有缺少的索引）。

	4.	索引完成後使用 S（單一磁碟）或 A（全部已有索引的磁碟）搜尋。

	5.	日常更新建議使用 C（單一磁碟）或 B（全部已有索引的磁碟），不必每次 Full Build。
4.2 主選單

|選項 |功能                                     |使用時機           |

|:-:|---------------------------------------|---------------|

|`A`|Search ALL indexed drives              |跨所有已有有效索引的磁碟搜尋。|

|`B`|Incremental Update ALL indexed drives  |手動更新全部既有索引。    |

|`C`|Incremental Update ONE drive           |手動更新指定磁碟。      |

|`D`|Parallel Full Build / Rebuild ONE drive|首次建置或需要完整重建。   |

|`E`|Parallel Build MISSING drives          |補建尚無有效索引的磁碟。   |

|`F`|Index Statistics                       |查看索引數量、時間與效能資訊。|

|`S`|Search ONE drive                       |只查指定磁碟。        |

|`R`|Refresh                                |重新載入磁碟與索引狀態。   |

|`Q`|Quit                                   |關閉工具。          |
5. 搜尋方式與結果操作

在 S／A 搜尋介面中，先選擇比對模式，再輸入關鍵字。

|模式                   |規則                             |例子：搜尋 `test`                                       |

|---------------------|-------------------------------|---------------------------------------------------|

|**Contains** (`1`)   |文字出現在任意位置。多個空白分隔關鍵字需**全部包含**。  |`mytest.xlsx`、`test.txt` 皆符合。                      |

|**StartsWith** (`2`) |第一個關鍵字必須在**開頭**；其餘關鍵字只須出現在任意位置。|`test_report.xlsx` 符合；`mytest.xlsx` 不符合。           |

|**Exact** (`3`)      |目標文字與**單一關鍵字**完全相等。            |`test` 符合；`test.txt` 不符合。                          |

|**Name / Path** (`T`)|切換搜尋檔名或完整路徑。                   |Path 模式搜尋 `V:\Project` 可匹配以此開頭的完整路徑（搭配 StartsWith）。|

搜尋預設不分英文大小寫，使用 OrdinalIgnoreCase；test 與 TEST 視為符合。

搜尋期間預設即時顯示結果；Search ALL 使用統一編號，結果格式例如：

[1] [V:\] [FILE]

V:\Project\test_report.xlsx

[2] [D:\] [FOLDER]

D:\Tools\Test

	●	P：暫停／恢復搜尋；Q：停止當次搜尋。

	●	搜尋結束輸入 1：開啟第 1 筆檔案／資料夾。

	●	輸入 F1：若為檔案，以檔案總管定位；若為資料夾，開啟該資料夾。

	●	Enter：開始新搜尋；M：返回主選單。
預設最多保留／顯示 10,000 筆結果。 單磁碟搜尋預設達上限就停止掃描，因此達上限時 Matches found 不代表完整總筆數；多磁碟搜尋的現行實作則可繼續掃描並累計符合數。使用 Q 提前停止時，統計也僅涵蓋已掃描部分。
6. 自動增量更新排程

程式不必常駐。Windows 工作排程器會在下列時間啟動 FolderSearchAutoUpdate.ps1：

|排程   |時間          |執行內容              |

|-----|------------|------------------|

|第 1 次|每天 **09:00**|增量更新目前可存取且已有索引的磁碟。|

|第 2 次|每天 **12:00**|同上。               |

|第 3 次|每天 **16:00**|同上。               |
安裝排程（只需成功執行一次）

powershell.exe -NoProfile -File "D:\Tools\InstallFolderSearchSchedule.ps1"

安裝程式建立一個 Windows 排程工作，名稱為：

FolderSearch Auto Incremental Update

此工作包含三個每日觸發器；MultipleInstances = IgnoreNew 可避免前次尚未完成時再開啟新執行個體。自動更新腳本另外以 AutoUpdate.lock 避免重複自動執行。
網路磁碟注意：排程使用安裝時的使用者與 Interactive 登入模式，因此通常需要該使用者處於已登入狀態，且映射磁碟（如 V:\）在排程工作所使用的登入環境中可見。關機、登出、網路斷線或存取權限不足，都可能使工作延後、略過或失敗。這不是無人登入也能保證執行的伺服器服務。
檢查與移除排程

# 查看排程與最近執行資訊

Get-ScheduledTask -TaskName "FolderSearch Auto Incremental Update" |

    Get-ScheduledTaskInfo

# 若要取消自動排程（不會刪除索引或主程式）

Unregister-ScheduledTask -TaskName "FolderSearch Auto Incremental Update" -Confirm:$false

也可以開啟「工作排程器 → 工作排程器程式庫」檢查觸發器、執行結果與歷程記錄。目前儲存庫沒有附帶 RemoveFolderSearchSchedule.ps1；上述命令可直接移除工作。
查看自動更新日誌

目前程式實際寫入：

D:\Tools\Log\AutoUpdate.log

可用：

Get-Content -LiteralPath "D:\Tools\Log\AutoUpdate.log" -Tail 30

日誌記錄開始時間、電腦／使用者、更新磁碟、成功／失敗／略過、耗時及摘要。檔案達 10 MB 時會輪替為 AutoUpdate.log.old（保留一份舊日誌）。即使 AutoUpdate.lock 檔案仍存在，也不表示程序正在執行；是否被鎖定取決於執行中的檔案控制代碼。
7. 主要設定參數（FolderSearchV11.ps1 開頭）

|參數                         |目前值              |用途                          |

|---------------------------|-----------------|----------------------------|

|`$AppName`                 |`FolderSearchV83`|決定 `%LOCALAPPDATA%` 下的索引資料夾。|

|`$FullBuildThrottleLimit`  |`32`             |Full Build 的最大平行數。          |

|`$FullBuildBatchSize`      |`256`            |Full Build 每批處理的目錄數。        |

|`$IncrementalThrottleLimit`|`32`             |增量目錄檢查最大平行數。                |

|`$SearchThrottleLimit`     |`4`              |Search ALL 的最大平行數。          |

|`$MaxDisplayResults`       |`10000`          |搜尋結果顯示／保留上限。                |

|`$ShowResultsImmediately`  |`$true`          |找到結果即顯示。                    |

|`$FastSearchStopAtLimit`   |`$true`          |單磁碟搜尋達上限時停止。                |

|`$RetryCount`              |`3`              |目錄存取失敗重試設定。                 |

|`$AllowPartialIndex`       |`$false`         |遇到無法接受的掃描失敗時，不提交不完整索引。      |

**調校建議：**先保留預設值，再根據磁碟、網路與硬體 I/O 實測調整；平行數提高並不保證搜尋速度同比例提升。
8. 部署差異與已知注意事項

	1.	本機版 vs. Server 版 BAT：FolderSearchV11.bat 目前從 D:\Tools\FolderSearchV11.ps1 啟動；儲存庫中的 FolderSearchV11- sever version.bat 則從預設的網路映射磁碟路徑啟動。Server 版 BAT 不會自動把各台電腦的索引集中到伺服器；程式仍使用執行者自己的 %LOCALAPPDATA%\FolderSearchV83。不同電腦要共用索引，需要另外調整架構。

	2.	**UNC 路徑：**從 \\Server\Share\... 啟動 BAT 時，CMD 可能顯示「不支援 UNC 作為目前工作目錄」。這與 PowerShell 執行權限問題是兩回事；必要時調整 BAT 的工作目錄（例如使用 pushd）。

	3.	**PowerShell 簽章限制：**若看到「未經數位簽署」或 UnauthorizedAccess，先執行 Get-ExecutionPolicy -List；公司群組原則可能無法透過系統管理員或 -ExecutionPolicy Bypass 解除，應由 IT 管理員核准或部署已簽署腳本。

	4.	**既有版本字樣未完全更新：**部分 V11 畫面標題及 .meta.json 的 Version 欄位仍使用 V10.4／10.4，但實際主程式檔名為 FolderSearchV11.ps1。勿只以畫面標題判斷部署版本。

	5.	排程安裝程式的提示路徑不一致：InstallFolderSearchSchedule.ps1 成功訊息仍顯示舊版 %LOCALAPPDATA%\FolderSearchV83\AutoUpdate.log；實際 V11 自動更新程式寫入的是 D:\Tools\Log\AutoUpdate.log。

	6.	**索引不是即時更新：**僅搜尋最後一次 Full Build／Incremental Update 已同步的名稱和路徑。若目錄修改時間未反映變更，增量索引可能過期。

	7.	**部署路徑是寫死的：**若不安裝在 D:\Tools\，需同步修改 BAT、FolderSearchAutoUpdate.ps1、InstallFolderSearchSchedule.ps1 中對應的檔案路徑；排程已建立時，也需更新工作設定。
9. 程式碼主要模組

|檔案                               |關鍵函式／模組                                                                              |責任                        |

|---------------------------------|-------------------------------------------------------------------------------------|--------------------------|

|`FolderSearchV11.ps1`            |`Get-AvailableDrives`、`Get-IndexPaths`                                               |磁碟偵測與索引位置。                |

|                                 |`Build-FullIndex`、`Invoke-ParallelDirectoryEnumeration`                              |完整索引與平行掃描。                |

|                                 |`Invoke-ParallelDirectoryProbe`、`Update-IncrementalIndex`、`Scan-NewSubtree`          |增量檢查、差異比對、子樹補掃與索引重建。      |

|                                 |`Search-OneIndex`、`Search-IndexesFast`、`Start-Search`                                |單碟／多碟搜尋、即時輸出、互動操作。        |

|                                 |`Load-DirectoryStates`、`Save-DirectoryStates`、`Commit-IndexSet`、`Commit-MetadataOnly`|狀態檔與提交保護。                 |

|                                 |`Show-MainMenu`、`Show-IndexStatistics`                                               |主選單及統計介面。                 |

|`FolderSearchAutoUpdate.ps1`     |`Write-AutoLog`、`FolderSearchLibraryMode`、鎖定檔控制                                      |載入主程式功能並自動更新所有已有索引的磁碟。    |

|`InstallFolderSearchSchedule.ps1`|`New-ScheduledTaskTrigger`、`Register-ScheduledTask`                                  |建立三個時間觸發器及一個 Windows 工作排程。|

|`FolderSearchV11.bat`            |`powershell.exe -File`                                                               |啟動本機版主程式並保留結束碼視窗。         |


**使用原則：**首次建立索引用 D／E，日常查詢用 S／A，日常手動同步用 C／B，每日固定同步則安裝工作排程。索引與自動更新日誌請保留在執行電腦，不要上傳公開儲存庫。
 
