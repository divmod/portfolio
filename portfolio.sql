--
-- This sequence will give us unique numbers for portfoloio id
-- Sequences are an Oracle-specific feature, but all databases
-- have something like them.
--
create sequence pid start with 1 increment by 1
                minvalue 0 nocycle cache 1024 noorder;

--
-- portfolio users.  
--
create table Users (
  username  varchar(64) not null primary key,
  password VARCHAR(64) NOT NULL
    constraint l_passwd CHECK (password LIKE '________%')
);


--
-- Portfolio
--
CREATE TABLE Portfolio (
  pid number not null primary key,
  username VARCHAR(64) not null references Users(username) ON DELETE cascade,
  name  VARCHAR(64) not null,
  constraint pname_unique UNIQUE(name,username),
  cashamt real not null,
  strategy char not null
);

--
-- Holdings
--
create table Holdings (
  id number not null references Portfolio(pid),
  datestamp number not null,
  symbol VARCHAR(10) not null,
  quantity number not null,
  iinvest real not null,
  constraint holding_unique UNIQUE (id,datestamp,symbol)
);


--
-- StocksDaily for new stocks
--
--create table OurStocksDaily(
--    symbol char(16) not null,
--    datestamp number not null,
--    open real not null,
--    high real not null,
--    low real not null,
--    close real not null,
--    volume real not null,
--    constraint OurStocksDaily_unique UNIQUE (symbol, datestamp)
--);

--
-- MarketDaily for daily market values
--

create table MarketDaily(
	datestamp number primary key,
	close real not null,
	constraint MarketDaily_unique UNIQUE (datestamp,close)
);

create table NewStocks(
    symbol VARCHAR(10) not null,
    datestamp number not null,
    open real not null,
    high real not null,
    low real not null,
    close real not null,
    volume real not null,
    constraint OurStocksDaily_unique UNIQUE (symbol, datestamp)
);

create table MarketDaily(
    datestamp number primary key,
    close real not null,
    constraint MarketDaily_unique UNIQUE(datestamp, close)
);
--
-- Create the required users
--
INSERT INTO Users (username,password) VALUES ('none','nonenone');
INSERT INTO Users (username,password) VALUES ('root','rootroot');

--
-- And what portfolios they own
--
INSERT INTO Portfolio(pid, username, name, cashamt, strategy) VALUES(pid.nextval,'root','myportfolio', 10000.00, 'b');
