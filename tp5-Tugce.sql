--1. Proposer un sch�ma de base de donn�es comportant les relations PERSONNE, LIVRE et EMPRUNT
--pour mod�liser cet �nonc� et impl�mentez cette base de donn�es en SQL avec les cl�s, les cl�s primaires
--et les cl�s �trang�res.

CREATE TABLE ADRESSE
(
   AID INT PRIMARY KEY NOT NULL,
	 Ville VARCHAR(50) NULL
);
CREATE TABLE LIVRE
(
   ISBN INT PRIMARY KEY NOT NULL,
	 tire VARCHAR(150) NOT NULL,
	 type VARCHAR(50) NOT NULL,
	 nPage INT NOT NULL
);
 CREATE TABLE PERSONNE
(
   PID INT PRIMARY KEY NOT NULL,
	 nom VARCHAR(50) NULL,
	 prenom VARCHAR(50) NULL,
	 AID INT NULL, 
	 FOREIGN KEY(AID) REFERENCES ADRESSE(AID),
	 credits INT NULL
);
CREATE TABLE PRETE
(
   ISBN INT NOT NULL,
   FOREIGN KEY(ISBN) REFERENCES LIVRE(ISBN),
	 PID INT NOT NULL,
	 FOREIGN KEY(PID) REFERENCES PERSONNE(PID) ,
	 Date DATE NULL,
	 Heure TIME(0) NULL
);

 CREATE TABLE EMPRUNT
(
   ISBN INT NOT NULL,
   FOREIGN KEY(ISBN) REFERENCES LIVRE(ISBN),
	 PID INT NOT NULL,
	 FOREIGN KEY(PID) REFERENCES PERSONNE(PID) ,
	 Date DATE NULL
);


-- insert
--2. Peuplez la base de donn�e avec un jeu petit d�essai comprenant un maximum de cas limites (e.g., livre
--non-emprunt� -> ISBN 1, personne sans emprunt->PID 3, emprunteur de son propre livre -> PID 2, ISBN 2).

INSERT INTO ADRESSE VALUES (1,'Lyon'),(2,'Paris'),(3,'Bordeaux');
INSERT INTO PERSONNE VALUES (1,'Brown','Jhon',2,4),(2,'Star','Lane',1,4),(3,'Felix','Ann',3,0),(4,'Lyn','Slyv',1,0);
INSERT INTO LIVRE VALUES (1,'book1','novel',90), (2,'book2','novel',290),(3,'book3','magazin',60);
INSERT INTO PRETE VALUES (1,1,'2022-04-29', '09:30:00'), (2,2,'2022-03-19', '15:40:00'), (3,3,'2022-04-01', '11:25:00');
INSERT INTO EMPRUNT VALUES (3,1,'2022-05-02'),(2,2,'2022-04-30');

--3. Implantez la d�pendance qui stipule qu�un emprunteur doit n�cessairement �tre un pr�teur (essayer
--d�abord de le faire avec une clef �trang�re et un CHECK). 

-- Impossible � faire avec un check
-- Trigger sur l'ajout dans la table emprunt, qui verifie si l'emprunteur est un preteur


CREATE OR REPLACE FUNCTION check_emprunt() RETURNS TRIGGER AS $$
  DECLARE 
    ID INT;
  BEGIN 
    SELECT DISTINCT P.PID INTO ID 
    FROM PRETE AS P
    WHERE P.PID = NEW.PID;
    IF ID IS NULL THEN 
      RAISE EXCEPTION 'Il faut avoir pr�t� au moins un livre pour l emprunter';
    END IF;
      RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_emprunt ON EMPRUNT;
CREATE TRIGGER check_emprAsPreteur
  BEFORE INSERT ON EMPRUNT
    FOR EACH ROW 
      EXECUTE PROCEDURE check_emprunt();


-- Exemple de tentative d'insertion qui ne fonctionne plus
INSERT INTO EMPRUNT VALUES (3,5,'2022-05-02');

--4. La r�gle de gestion est que pour le d�p�t d�un livre, on re�oit 4 cr�dits d�emprunts. Un cr�dit est
--retir� � chaque emprunt. Pour aider � la gestion, un attribut calcul�e Credits est ajout� � la relation
--PERSONNE. Implantez les d�clencheurs en insertion n�cessaires pour automatiser la maintenance du
--nombre de cr�dits. On assurera en particulier la r�gle m�tier suivante : � une personne ne peut pas
--effectuer d�emprunt si elle ne poss�de pas les cr�dits susants, sauf si le livre est � elle �

-- trigger sur l'insertion dans la table livre qui ajoute 4 au champs credit dans la table personne
CREATE OR REPLACE FUNCTION add_credit() RETURNS TRIGGER AS $$
  BEGIN 
    UPDATE PERSONNE 
    SET credits = credits +4
    WHERE PID = new.PID;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS add_credit ON PRETE;

CREATE TRIGGER add_credit
  AFTER INSERT ON PRETE
    FOR EACH ROW 
      EXECUTE PROCEDURE add_credit();

-- trigger sur l'insertion dans la table emprunt qui (retire 1 au credit de la table personne et empeche l'emprunt si plus de credits) sauf si l'emprunteur est le preteur
CREATE OR REPLACE FUNCTION check_emprunt() RETURNS TRIGGER AS $$
  DECLARE 
    ID INT;
    credit INT;
  BEGIN 
    SELECT P.PID INTO ID 
    FROM PRETE AS P
    WHERE P.ISBN = NEW.ISBN;
    IF ID = new.PID THEN 
      RETURN NEW;
    END IF;
      SELECT PS.credits into credit 
      FROM PERSONNE AS PS
      WHERE PS.PID = new.PID;
      IF credit > 0 THEN
        UPDATE PERSONNE
        SET credits = credit -1 
        WHERE PID = new.PID;
        RETURN NEW;
      END IF;
      RAISE EXCEPTION 'L emprunteur doit avoir au moins 1 cr�dit';
      
  END;
$$ LANGUAGE plpgsql;




DROP TRIGGER IF EXISTS check_emprunt ON EMPRUNT;
CREATE TRIGGER check_emprunt
  BEFORE INSERT ON EMPRUNT
    FOR EACH ROW 
      EXECUTE PROCEDURE check_emprunt();


-- Exemple de tentative d'insertion qui ne fonctionne plus
INSERT INTO EMPRUNT VALUES (3,2,'2022-05-07');

--5. Des frais de participation � la gestion sont factur�s chaque ann�e aux utilisateurs. Ils sont en fonction
--du nombre d�emprunts, et progressifs en fonction du rapport (nombre emprunt�s/nombre pr�t�s) pour
--chaque personne.
--1. Si une personne a emprunt� entre 0 et 2 fois (inclus) le nombre de livres qu�elle a pr�t�, le tarif
--annuel est de 1e.
--2. Si le rapport est strictement sup�rieur � 2, le tarif est de 2 e.
--3. Une personne peut emprunter ses propres livres sans frais.
--Implantez une fonction PL/SQL qui, en fonction du num�ro d�une personne, retourne le montant en
--cours de ses frais de participation. Utilisez ensuite cette fonction dans une requ�te pour faire acher
--les frais d�s par chaque personne.
 --DROP FUNCTION calcul_facture(integer)

CREATE OR REPLACE FUNCTION calcul_facture(ID INT) RETURNS int AS $BODY$
  DECLARE
     nEmp INT;
	 nPret INT;
	
  BEGIN 
    SELECT COUNT (E.PID), COUNT (PR.PID)
	INTO nEmp , nPret
    FROM EMPRUNT AS E
	INNER JOIN PERSONNE AS P ON P.PID=E.PID
	INNER JOIN PRETE AS PR ON PR.PID= P.PID
    WHERE E.PID = ID AND PR.PID = ID AND E.ISBN <> PR.ISBN;
    IF nEmp/nPret >=0 AND nEmp/nPret<=2  THEN 
       raise notice 'le tarif annuel est de 1e';
      return 1;
    END IF;
    SELECT COUNT (E.PID), COUNT (PR.PID)
	INTO nEmp , nPret
    FROM EMPRUNT AS E
	INNER JOIN PERSONNE AS P ON P.PID=E.PID
	INNER JOIN PRETE AS PR ON PR.PID= P.PID
    WHERE E.PID = ID AND PR.PID = ID AND E.ISBN <> PR.ISBN;
    IF nEmp/nPret>2  THEN 
      raise notice 'le tarif est de 2 e';
     return 2;
      END IF;
      raise notice 'Une personne peut emprunter ses propres livres sans frais';
     return 0;
    END;
$BODY$ LANGUAGE plpgsql;


SELECT calcul_facture(4);



--6. Cette mod�lisation a de nombreux probl�mes si on souhaite r�ellement s�en servir. Quels sont-ils?
--Plusieurs personnes peuvent emprunter le m�me livre en m�me temps. En r�alit� c'est impossible.