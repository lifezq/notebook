使用 go-ethereum 1.6 Clique PoA consensus 建立 Private chain (1)
------------------------

## Ethereum Proof of Authority

在 Ethereum 官方的共識機制是使用 PoW，Miner 必須靠使用算力去解決密碼學問題來取得寫帳(打包 Block)權。但 PoW 機制在私有鏈或聯盟鏈上並不是一個經濟的共識機制，私有鏈的維運者必須花費多餘的算力來維持私有鏈的運作。

而 Proof of Authority 思維是直接指定哪些節點有寫帳權，其他節點透過演算法如果是被授權的節點打包 Block 則判定 Block 有效。

Ethereum Client 有各種版本的實作，之前 [Parity](https://github.com/paritytech/parity) 版本的實作就有提供 PoA 的共識機制(介紹)。而在前段時間發佈的 geth 1.6 也支援了 PoA 的共識機制。不過 geth 的 PoA 使用方法跟機制和 Parity 的版本不同，geth 實作了 [ethereum/EIPs#225](https://github.com/ethereum/EIPs/issues/225) 一個稱作 Clique 的共識機制。所以這篇主要筆記如何建立一個 geth Clique Private chain。
情境中會使用 4 個節點，分別代表兩個普通的節點發起交易，一個創世塊指定的授權節點，一個後期加入的授權節點來玩玩 Clique 。

## 安裝 geth

由於 go-ethereum 使用 golang 開發的，所有的程式都被編譯成單一的可執行檔了，直接下載下來就可以直接執行。
geth & tools 1.6 — https://ethereum.github.io/go-ethereum/downloads/
找到相對應 OS 後下載，記得下載 geth & tools 的版本，接下來會使用 geth 1.6 版本的一個創 Private chain 的工具 [puppeth](https://blog.ethereum.org/2017/04/14/geth-1-6-puppeth-master/) 來建立 Clique Private chain。
最後記得將這些執行檔加入 PATH 方便呼叫。

## 環境準備

待會要建置的環境將會使用 4 個 ethereum 節點，並且全部節點跑在同一台機器上，這樣比較省事。先創好 4 個資料夾，分別叫 node1 node2 signer1 signer2 ，node 是一般的 ethereum client，signer 在接下來的情境中當成打包 block 的角色。

    -> % ls
    node1 node2 signer1 signer2
    
## 建立 Ethereum 帳號
接著我們要替這四個角色各建立一個 Ethereum 帳號。

     frank@frank-linux [10:51:22 AM] [~/src/eth-poa] 
    -> % cd node1
    frank@frank-linux [10:55:08 AM] [~/src/eth-poa/node1] 
    -> % geth --datadir ./data account new
    WARN [04–18|10:55:30] No etherbase set and no accounts found as default 
    Your new account is locked with a password. Please give a password. Do not forget this password.
    Passphrase: 
    Repeat passphrase: 
    Address: {c7873030c2532aafe540d9dfd02a08330ee06465}
    
在這步驟切換到每個目錄底下，指令 geth --datadir ./data account new 這段指令是指要使用當下目錄底下的 data 目錄當作 geth 存放資料的地方，並且創一個新的 Account。在剛剛建立的 node1, node2, signer1, signer2 都下相同指令創一個帳號。
以下是我創好的每個角色的 Account address:

> - node1: c7873030c2532aafe540d9dfd02a08330ee06465
> - node2: 6d650780d493056f679a30b2c65cfa5e07835ad6
> - signer1: 5cc640ae524f70c39081d65bc699b3b61a67bd3f
> - signer2: 0fe2d8747d24156b342c9fa5c5e7138cf4047a8d

創好帳號後就可以開始建立 Private chain 了

## 建立創世塊設定
由於 Clique 並不像 Parity 版本的 PoA 靠設定檔設定授權的節點。Clique 是將授權節點的相關資訊放在 Block Header 中，所以我們必須對創世塊做一些設定才可以讓授權機制生效。(但這並不意味著新增或刪除授權節點需要更換創世塊，晚點介紹怎麼新增授權節點)
Clique 是將授權的資訊放在 extraData 中，但資料結構的格式並沒有那麼直覺，所以在此使用 geth 1.6 提供的建立 Private Chain 的工具 puppeth 來建立創世塊，puppeth 是各互動式的程式，直接啟動照著指示輸入相關資訊。

    frank@frank-linux [11:19:16 AM] [~/src/eth-poa] 
    -> % puppeth
    + — — — — — — — — — — — — — — — — — — — — — — — — — — — — — -+
    | Welcome to puppeth, your Ethereum private network manager |
    | |
    | This tool lets you create a new Ethereum network down to |
    | the genesis block, bootnodes, miners and ethstats servers |
    | without the hassle that it would normally entail. |
    | |
    | Puppeth uses SSH to dial in to remote servers, and builds |
    | its network components out of Docker containers using the |
    | docker-compose toolset. |
    + — — — — — — — — — — — — — — — — — — — — — — — — — — — — — -+
    Please specify a network name to administer (no spaces, please)
    > poa_for_fun
 
 這裡會希望你給你的 Private chain 一個名字
 
    Sweet, you can set this via — network=poa_for_fun next time!
    INFO [04–18|11:19:21] Administering Ethereum network name=poa_for_fun
    WARN [04–18|11:19:21] No previous configurations found path=/home/frank/.puppeth/poa_for_fun
    What would you like to do? (default = stats)
     1. Show network stats
     2. Configure new genesis
     3. Track new remote server
     4. Deploy network components
    > 2
    
這裡選 2 ，要建立一個新的創世塊設定

    Which consensus engine to use? (default = clique)
     1. Ethash — proof-of-work
     2. Clique — proof-of-authority
    > 2
    
共識機制，選 2，Clique PoA

    How many seconds should blocks take? (default = 15)
    > 10
    
多少秒數會產出一個 Block，在這裡設 10 秒。當然你可以自己設定你想要的

    Which accounts are allowed to seal? (mandatory at least one)
    > 0x5cc640ae524f70c39081d65bc699b3b61a67bd3f
    > 0x
    
指定一個 Account address 作為授權打包的角色。這裡使用上面產出的 Signer1 的 address。

    Which accounts should be pre-funded? (advisable at least one)
    > 0xc7873030c2532aafe540d9dfd02a08330ee06465
    > 0x5cc640ae524f70c39081d65bc699b3b61a67bd3f
    > 0x
    
指定要不要事先給一些 ether。這裡選 node1 和 signer1 的 address，當然這隨你指定

    Specify your chain/network ID if you want an explicit one (default = random)
    >
Network Id，直接用 random

    Anything fun to embed into the genesis block? (max 32 bytes)
    >
    
沒什麼需要特別加入 genesis 的，留空

    What would you like to do? (default = stats)
    1. Show network stats
    2. Save existing genesis
    3. Track new remote server
    4. Deploy network components
    > 2
    
選 2 存檔

    Which file to save the genesis into? (default = poa_for_fun.json)
    > 
    INFO [04–18|11:19:50] Exported existing genesis block
    What would you like to do? (default = stats)
    1. Show network stats
    2. Save existing genesis
    3. Track new remote server
    4. Deploy network components
    > ^C
    
ctrl+c 離開，會在當下目錄看到一個 poa_for_fun.json 檔案。
替 4 個節點初始化 Private chain
使用 geth init 指令，分別替換 4 個 node 的 datadir

    frank@frank-linux [11:38:07 AM] [~/src/eth-poa] 
    -> % ls
    node1 node2 poa_for_fun.json signer1 signer2
    frank@frank-linux [11:38:07 AM] [~/src/eth-poa] 
    -> % geth --datadir node1/data init poa_for_fun.json 
    INFO [04–18|11:39:10] Allocated cache and file handles database=/home/frank/src/eth-poa/node1/data/geth/chaindata cache=128 handles=1024
    INFO [04–18|11:39:10] Writing custom genesis block 
    INFO [04–18|11:39:10] Successfully wrote genesis state hash=5722d7…47e737
    frank@frank-linux [11:39:10 AM] [~/src/eth-poa] 
    -> % geth --datadir node2/data init poa_for_fun.json
    INFO [04–18|11:39:14] Allocated cache and file handles database=/home/frank/src/eth-poa/node2/data/geth/chaindata cache=128 handles=1024
    INFO [04–18|11:39:14] Writing custom genesis block 
    INFO [04–18|11:39:14] Successfully wrote genesis state hash=5722d7…47e737
    frank@frank-linux [11:39:14 AM] [~/src/eth-poa] 
    -> % geth --datadir signer1/data init poa_for_fun.json
    INFO [04–18|11:39:21] Allocated cache and file handles database=/home/frank/src/eth-poa/signer1/data/geth/chaindata cache=128 handles=1024
    INFO [04–18|11:39:21] Writing custom genesis block 
    INFO [04–18|11:39:21] Successfully wrote genesis state hash=5722d7…47e737
    frank@frank-linux [11:39:21 AM] [~/src/eth-poa] 
    -> % geth --datadir signer2/data init poa_for_fun.json
    INFO [04–18|11:39:24] Allocated cache and file handles database=/home/frank/src/eth-poa/signer2/data/geth/chaindata cache=128 handles=1024
    INFO [04–18|11:39:24] Writing custom genesis block 
    INFO [04–18|11:39:24] Successfully wrote genesis state hash=5722d7…47e737

![img_01](https://cdn-images-1.medium.com/max/800/1*OY81CDRDI9kFou_kqOD65w.png)

到目前我們已經準備好讓節點可以啟動和互相連線了。

## 啟動 geth client 並設定 peers 間的連線

分別在 node1, node2 目錄使用指令啟動 geth
    geth --datadir ./data --networkid 55661 --port 2000 console
這裡的參數需要特別注意。

> - datadir 參數沒問題，先前的步驟已經在每個節點各自的目錄都建立了 data 目錄。
> - networkid 大家一定都要用同一個值才可以互相連線。
> - port 用來讓 geth 跟其他 geth 連線所 listen 的一個 port，由於四個節點都在本機，所以這裡必須都指定不同的值，以下使用 node1 2000, node2 2001, signer1 2002, signer2 2003 當範例。

如果節點是授權打包 block 的節點，那你啟動時要先 unlock 你的 account，這樣才可以進行交易的打包。多帶一個 unlock 參數，以及你要解鎖的 account address。啟動後會要求輸入當時創 account 時的 passphrase。所以在這裡啟動 signer1 和 signer2 時都要用 unlock 參數帶入他們各自的 address 解鎖。

    geth --datadir ./data --networkid 55661 --port 2002 --unlock 5cc640ae524f70c39081d65bc699b3b61a67bd3f console
    
啟動後會看到這樣的結果，如果沒噴任何錯誤就是啟動成功了，同時會啟動一個 console 的互動介面，可以打像是 admin.nodeInfo 這類的指令來操作 geth。

![img_02](https://cdn-images-1.medium.com/max/800/1*3Q9LPhEvKx8LaG-CErz3WQ.png)

在啟動訊息中有一段

    INFO [04–18|12:01:31] RLPx listener up self=enode://87692411dd1af113ccc04d3f6d3d7d47366c81e595525c861c7a3c902ca0a86f46e8d7a837f431536822dbb012f68d942ed96910385805864e990efdf3839a1e@[::]:2000
    
由於目前是在 private chain 上，沒有設定啟動節點也沒設定 static node，各節點啟動後是沒辦法找到對方的。所以在此我們把 node2, singer1, signer2 都加入 node1 為自己的節點連上。geth 要連上對方的節點就必須好 enode://<id>@<ip>:<port>這格式，複製剛剛啟動 node1 時出現的 enode 資訊將 [::] 換為 127.0.0.1 讓其他節點加入就可以連上了。
在 node2, signer1, signer2 的 geth console 頁面分別打入指令

    >admin.addPeer(“enode://87692411dd1af113ccc04d3f6d3d7d47366c81e595525c861c7a3c902ca0a86f46e8d7a837f431536822dbb012f68d942ed96910385805864e990efdf3839a1e@127.0.0.1:2000”)
    
完成後回到 node1 的 geth console 打入 admin.peers 應該要看到三個節點資訊。

到這步 geth 節點已經連上可以開始進行 PoA 挖礦和交易了。

## 啟動 Miner

到 signer1 的 console 打入 miner.start() 這時候如果你本機之前沒有啟動過 miner，geth 會先產生 DAG 等 DAG 產生完後就會開始挖礦了。
在 signer1 的 console 會出現正在 mining 的訊息。

![img_03](https://cdn-images-1.medium.com/max/800/1*PFGEmC8-hhX5qNcqa78BnQ.png)

其他節點則會收到 import block 的訊息。

## Make a transaction

到這裡 Clique 的 Private chain 已經設定完成了，我們可以開始在這條鏈上做一些交易。接下來為了方便會使用 geth 的 console 來做 send ether 交易，如果你不習慣的話也可以使用 mist 這類的 UI 錢包來做。

## node1 console
還記得在建立創世塊的時候有先給了 node1 和 signer1 的 address 一些 ether 吧？先用這令看看這些 ether 有沒有真的在鏈上。使用指令 eth.getBalance("<Address>") 來查詢。

    > eth.getBalance(“c7873030c2532aafe540d9dfd02a08330ee06465”)
    9.04625697166532776746648320380374280103671755200316906558262375061821325312e+74
    > eth.getBalance(“6d650780d493056f679a30b2c65cfa5e07835ad6”)
    0
    >
    
確定 node1 有 ether 但 node2 沒有，接著用 eth.sendTransaction 指令來把一些 ether 從 node1 轉到 node2 吧。
現在 node1 的 console 把自己的 Account unlock

    > personal.unlockAccount("c7873030c2532aafe540d9dfd02a08330ee06465")
    Unlock account c7873030c2532aafe540d9dfd02a08330ee06465
    Passphrase:
    true
    >
    
轉出 0.05 ether 到 6d650780d493056f679a30b2c65cfa5e07835ad6

    >eth.sendTransaction({from:"c7873030c2532aafe540d9dfd02a08330ee06465", to:"6d650780d493056f679a30b2c65cfa5e07835ad6", value: web3.toWei(0.05, "ether")})
    INFO [04-18|12:39:53] Submitted transaction                    fullhash=0xa7a9da239b8f96b9f6fe4007ee88773915f034be2365b2dab234fd8c0545aa37 recipient=0xc7873030c2532aafe540d9dfd02a08330ee06465
    "0xa7a9da239b8f96b9f6fe4007ee88773915f034be2365b2dab234fd8c0545aa37"
    >
    
如果你 signer1 的 miner 沒關掉的話，在幾秒後就會看到一個含有一筆交易的 block 產出

![img_04](https://cdn-images-1.medium.com/max/800/1*JqfUkMGh7hIvQ2CmGh9QFw.png)

再來看看 node1 和 node2 的 ether

    > eth.getBalance("c7873030c2532aafe540d9dfd02a08330ee06465")
    9.04625697166532776746648320380374280103671755200316906558211535061821325312e+74
    > eth.getBalance("6d650780d493056f679a30b2c65cfa5e07835ad6")
    50000000000000000
    >
    
交易完成！

## 加入一個新的信任節點

在 Clique 共識機制中是使用 Clique 提供的 API 來做節點管理，現在只 demo 加入節點進入信任名單。
signer2
signer2 是一開始沒設定在創世塊中信任列表的節點，如果這時候讓它啟動 miner 會怎麼樣呢？會噴一個未授權的錯誤
    > miner.start()
    INFO [04-18|12:49:51] Starting mining operation
    null
    > INFO [04-18|12:49:51] Commit new mining work                   number=46 txs=0 uncles=0 elapsed=284.189µs
    WARN [04-18|12:49:51] Block sealing failed                     err=unauthorized
    
必須回到已經在授權名單內的節點將新的節點加入。
signer1
回到 signer1 的 console 輸入加入的指令
    
    > clique.propose("0x0fe2d8747d24156b342c9fa5c5e7138cf4047a8d", true)
    
singer2
接著回到 signer2 的 console

![img_05](https://cdn-images-1.medium.com/max/800/1*h-lJsN6Ws-3Kx1RBi_YxsQ.png)

開始打包交易了

## 結語

由於 geth 1.6 才發佈不久，關於 Clique 的相關文章還蠻少的。提供如何使用 geth 1.6 建立一個 Clique private chain 的簡單教學，其實大部分都是我自己在建置時的筆記，內容省略了很多關於 Clique 的一些特性和原理，有興趣的建議直接看 ethereum/EIPs#225。希望這篇可以幫助到使用 geth 但又想用用 PoA 共識機制的同伴們XD

[阅读原文](https://medium.com/taipei-ethereum-meetup/%E4%BD%BF%E7%94%A8-go-ethereum-1-6-clique-poa-consensus-%E5%BB%BA%E7%AB%8B-private-chain-1-4d359f28feff)


相关参考  

[建立 Go Ethereum 私有網路鏈](https://kairen.github.io/2017/05/25/blockchain/multi-node-geth/)
