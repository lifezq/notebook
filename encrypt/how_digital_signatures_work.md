## 数字签名工作原理 
 数字签名是指发送方用自己的私钥对数字指纹进行加密后所得的数据，其中包括非对称密钥加密和数字签名两个过程，在可以给数据加密的同时，也可用于接收方验证发送方身份的合法性。采用数字签名时，接收方需要使用发送方的公钥才能解开数字签名得到数字指纹。
       数字指纹又称为信息摘要，是指发送方通过HASH算法对明文信息计算后得出的数据。采用数字指纹时，发送方会将本端对明文进哈希运算后生成的数字指纹（还要经过数字签名），以及采用对端公钥对明文进行加密后生成的密文一起发送给接收方，接收方用同样的HASH算法对明文计算生成的数据指纹，与收到的数字指纹进行匹配，如果一致，便可确定明文信息没有被篡改。
      数字签名的加解密过程如图1-20所示。甲也要事先获得乙的公钥，具体说明如下（对应图中的数字序号）：



![img_01](https://github.com/lifezq/notebook/blob/master/imgs/encrypt/20170925082940871.png)


                               图1-20  数字签名的加解密过程示意图
                               

（1）甲使用乙的公钥对明文进行加密，生成密文信息。

（2）甲使用HASH算法对明文进行HASH运算，生成数字指纹。

（3）甲使用自己的私钥对数字指纹进行加密，生成数字签名。

（4）甲将密文信息和数字签名一起发送给乙。

（5）乙使用甲的公钥对数字签名进行解密，得到数字指纹。

（6）乙接收到甲的加密信息后，使用自己的私钥对密文信息进行解密，得到最初的明文。

（7）乙使用HASH算法对还原出的明文用与甲所使用的相同HASH算法进行HASH运算，生成数字指纹。然后乙将生成的数字指纹与从甲得到的数字指纹进行比较，如果一致，乙接受明文；如果不一致，乙丢弃明文。

       从以上数字签名的加/解密过程中可以看出，数字签名技术不但证明了信息未被篡改，还证明了发送方的身份。数字签名和数字信封技术也可以组合使用。但是，数字签名技术也还有一个问题，获取到对方的公钥可能被篡改，并且无法发现。

       试想一下，如果攻击者一开始就截获了乙发给甲公钥的文件，然后就可用狸猫换太子的方法更改乙的公钥，最终可能导致甲获得的是攻击者的公钥，而非乙的。

具体过程是这样的：攻击者拦截了乙发给甲的公钥信息，用自己的私钥对伪造的公钥信息进行数字签名，然后与使用甲的公钥（攻击者也已获知了甲对外公开的公钥）进行加密的、伪造的乙的公钥信息一起发给甲。甲收到加密信息后，利用自己的私钥可以成功解密出得到的明文（伪造的乙的公钥信息），因为这个信息的加密就是用甲的公钥进行的，并且也可以通过再次进行HASH运算验证该明文没有被篡改。此时，甲则始终认为这个信息是乙发送的，即认为该伪造的公钥信息就是乙的，结果甲再利用这个假的乙的公钥进行加密的数据发给乙时，乙肯定是总解密不了的。此时，需要一种方法确保一个特定的公钥属于一个特定的拥有者，那就是数字证书技术了。因为用户接收到其他用户的公钥数字证书时可以在证书颁发机构查询、验证的。

      【经验之谈】许多人分不清非对称密钥加密和数字签名的区别，其实很好理解。非对称加密用的是接收方的公钥进行数据加密的，密文到达对方后也是通过接收方自己的私钥进行解密，还原成明文，整个数据加密和解密过程用的都是接收方的密钥；而数字签名则完全相反，是通过发送方的私钥进行数据签名的，经签名的数据到达接收方后也是通过事先告知接收方的发送方的公钥进行解密，整个数据签名和解密的过程用的都是发送方的密钥。
