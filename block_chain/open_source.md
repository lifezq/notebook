[**Hyperledger**](https://github.com/hyperledger/hyperledger)    
 Hyperledger Project is a new Collaborative Project at The Linux Foundation. The technical community is just getting started and will be adding code to the repository in the coming weeks. Check hyperledger.org for more information about joining the mailing lists and participating in the conversations. http://www.hyperledger.org      

[**ethereum**](https://github.com/ethereum/go-ethereum)         
Official golang implementation of the Ethereum protocol.     
Automated builds are available for stable releases and the unstable master branch. Binary archives are published at https://geth.ethereum.org/downloads/.       

[**fabric**](https://github.com/fabric/fabric)        
Simple, Pythonic remote execution and deployment. http://fabfile.org       
Fabric is a Python (2.5-2.7) library and command-line tool for streamlining the use of SSH for application deployment or systems administration tasks.     

It provides a basic suite of operations for executing local or remote shell commands (normally or via sudo) and uploading/downloading files, as well as auxiliary functionality such as prompting the running user for input, or aborting execution.     

Typical use involves creating a Python module containing one or more functions, then executing them via the fab command-line tool. Below is a small but complete "fabfile" containing a single task:     

    from fabric.api import run

    def host_type():
        run('uname -s')
