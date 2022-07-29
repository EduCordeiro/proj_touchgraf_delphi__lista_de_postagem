unit uMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, FileCtrl,
  Dialogs, StdCtrls, Buttons, Mask, JvExMask, JvToolEdit,
  udatatypes_apps, ucore, ComCtrls, CheckLst, ZAbstractDataset, ZDataset,
  ExtCtrls, ClassParametrosDeEntrada, ClassExpressaoRegular;

type

  TfrmMain = class(TForm)
    btnSobre: TBitBtn;
    btnSair: TBitBtn;
    pgcMain: TPageControl;
    tbsEntrada: TTabSheet;
    tbsSaida: TTabSheet;
    tbsExecutar: TTabSheet;
    btnExecutar: TBitBtn;
    lblCaminhoArquivosEntrada: TLabel;
    btnSelecionarTodos: TBitBtn;
    btnLimparSelecao: TBitBtn;
    cltArquivos: TCheckListBox;
    lblInfos: TLabel;
    lblCaminhoArquivosSaida: TLabel;
    lblIdProcessamento: TLabel;
    lblIdProcessamentoValor: TLabel;
    lblNumeroDoLotePedido: TLabel;
    lblNumeroDoLotePedidoValor: TLabel;
    tsRelatorios: TTabSheet;
    lblLote: TLabel;
    edtLote: TEdit;
    btnPesquisar: TButton;
    mmoRelatorio: TMemo;
    rgTipoLote: TRadioGroup;
    edtSalvarRelatorio: TJvDirectoryEdit;
    lblSalvarRelatorio: TLabel;
    btnSalvarRelatorio: TButton;
    edtPathEntrada: TJvDirectoryEdit;
    edtPathSaida: TJvDirectoryEdit;
    btnConfereQuantidades: TButton;
    pnl_Numero_de_lotes: TPanel;
    pnl_Numero_de_objetos: TPanel;
    pnl_Peso_total: TPanel;
    lblDataPostagem: TLabel;
    dtpDataPostagem: TDateTimePicker;
    lblObservacoes: TLabel;
    edtObservacoes: TEdit;
    edtDefinirPedido: TEdit;
    lblPedidoManual: TLabel;
    chkImprimir: TCheckBox;
    chkFacRegistrado: TCheckBox;
    procedure btnSairClick(Sender: TObject);
    procedure btnSobreClick(Sender: TObject);
    procedure btnExecutarClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnSelecionarTodosClick(Sender: TObject);
    procedure btnLimparSelecaoClick(Sender: TObject);
    procedure cltArquivosClick(Sender: TObject);
    procedure DesmarcaAnteriores();
    procedure FormCreate(Sender: TObject);
    procedure btnPesquisarClick(Sender: TObject);
    procedure btnSalvarRelatorioClick(Sender: TObject);
    procedure edtPathEntradaChange(Sender: TObject);
    procedure btnConfereQuantidadesClick(Sender: TObject);
    procedure ConfereQuantidades(Var iNumeroDeLotes, iNumeroDeObjetos, iPeso: Integer);
    procedure chkFacRegistradoClick(Sender: TObject);
    procedure pgcMainChange(Sender: TObject);

  private
    { Private declarations }

    {
      Vari�vel privada que cont�m todos os par�metros de entrada do Form para
      uCore.

      Todas as entradas de conponentes gr�ficos devem ser declarados no record
      RParametrosEntrada que se econtra no ucore.pas.

      E passadas diretamente para a Fun��o Executar, onde a mesma far� o
      relacionamento do par�metro gr�fico com o par�metro do record.

    }

    procedure AboutApplication(autores: String);
    procedure AtualizarArquivosEntrada(Path: String; focoAutomatico: boolean=false);
    function  ValidarParametrosInformados(ParametrosDeEntrada: TParametrosDeEntrada): Boolean;
    function Executar(): Boolean;
    procedure AtualizarListagemDeArquivos(path: String);
    procedure AtualizarQtdeArquivosMarcados();

    procedure LimparSelecao();
    procedure SelecionarTodos();
    procedure LogarParametrosDeEntrada(ParametrosDeEntrada: TParametrosDeEntrada);

    {Verifica se o programa j� est� aberto}
    function AplicacaoEstaAberta(NomeAPP: PChar): Boolean;
   {Converte String em Pchar}
    function StrToPChar(const Str: string): PChar;

    function GetUsuarioLogado(): String;


  public
    { Public declarations }

    sPathEntrada             : string;
    objCore                  : TCore;

  end;

var
  frmMain       : TfrmMain;
  bAppEstaAberto : Boolean;

implementation

{$R *.dfm}

procedure TfrmMain.btnSairClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfrmMain.btnSobreClick(Sender: TObject);
begin

  AboutApplication('Eduardo C. M. Monteiro');

end;

procedure TfrmMain.LogarParametrosDeEntrada(ParametrosDeEntrada: TParametrosDeEntrada);
var
  iContArquivos : Integer;
begin
  objCore.objLogar.Logar('[DEBUG] ID..............................: ' + ParametrosDeEntrada.ID_PROCESSAMENTO);
  objCore.objLogar.Logar('[DEBUG] ARQUIVOS SELECIONADOS...........: ');

  for iContArquivos := 0 TO ParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Count -1 DO
    objCore.objLogar.Logar('[DEBUG] -> ' + ParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Strings[iContArquivos]);

  objCore.objLogar.Logar('[DEBUG] INFORMA��ES.....................: ' + ParametrosDeEntrada.INFORMACAO_DOS_ARQUIVOS_SELECIONADOS);
  objCore.objLogar.Logar('[DEBUG] PATH ENTRADA....................: ' + ParametrosDeEntrada.PATHENTRADA);
  objCore.objLogar.Logar('[DEBUG] PATH SAIDA......................: ' + ParametrosDeEntrada.PATHSAIDA);
  objCore.objLogar.Logar('[DEBUG] PATH ARQUIVOS TEMPORARIOS.......: ' + ParametrosDeEntrada.PATHARQUIVO_TMP);
  objCore.objLogar.Logar('[DEBUG] TABELA DE PROCESSAMENTO.........: ' + ParametrosDeEntrada.TABELA_PROCESSAMENTO);
  objCore.objLogar.Logar('[DEBUG] TABELA DE PLANO DE TRIAGEM......: ' + ParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM);
  objCore.objLogar.Logar('[DEBUG] NUMERO DE REGISTROS POR SELECT..: ' + ParametrosDeEntrada.LIMITE_DE_SELECT_POR_INTERACOES_NA_MEMORIA);
end;

function TfrmMain.Executar(): Boolean;
var
  sListaMensagens: string;
  iNumeroDeErros: integer;

begin

  LogarParametrosDeEntrada(objCore.objParametrosDeEntrada);

  if not ValidarParametrosInformados(objCore.objParametrosDeEntrada) then
  begin
    showmessage('[ERRO] Erros ocorreram. Confira o arquivo de Log.');
    exit;
  end
  else
  begin

    btnExecutar.Enabled := False;

    btnExecutar.Enabled := false;
    screen.Cursor       := crSQLWait;

    objCore.MainLoop();

    btnExecutar.Enabled := true;
    screen.Cursor := crDefault;

  end;

end;

function TfrmMain.ValidarParametrosInformados(ParametrosDeEntrada: TParametrosDeEntrada): Boolean;
var
  bValido        : boolean;
  sMSG           : string;

begin

  bValido := true;
   //TODA SUA VALIDAD��O AQUI

  if ParametrosDeEntrada.LISTADEARQUIVOSDEENTRADA.Count <= 0  then
  begin
    bValido := False;
    sMSG    := '[ERRO] Nenhum arquivo selecionado. O programa ser� encerrado agora.'+#13#10#13#10;
    showmessage(sMSG);
    objCore.objLogar.Logar(sMSG);
  end;

  // flag que define se todos os par�metros est�o v�lidos.
  Result:= bValido;

end;

procedure TfrmMain.btnExecutarClick(Sender: TObject);
var
  ListaDeArquivosSelecionados: TStringList;
  iContArquivosSelecionados: Integer;
  sMSG : string;
begin
  try
    try

      ListaDeArquivosSelecionados:= TStringList.Create();
      for iContArquivosSelecionados:= 0 to cltArquivos.Count - 1 do
        if cltArquivos.Checked[iContArquivosSelecionados] then
          ListaDeArquivosSelecionados.Add(cltArquivos.Items[iContArquivosSelecionados]);

      objCore.objParametrosDeEntrada.ID_Processamento                              := lblIdProcessamentoValor.Caption;
      objCore.objParametrosDeEntrada.PathEntrada                                   := edtPathEntrada.Text;
      objCore.objParametrosDeEntrada.PathSaida                                     := edtPathSaida.Text;
      objCore.objParametrosDeEntrada.ListaDeArquivosDeEntrada                      := ListaDeArquivosSelecionados;

      objCore.objParametrosDeEntrada.INFORMACAO_DOS_ARQUIVOS_SELECIONADOS          := lblInfos.Caption;

      objCore.objParametrosDeEntrada.HORA_INICIO_PROCESSO                          := Now;

      objCore.objParametrosDeEntrada.FAC_REGISTRADO                                := chkFacRegistrado.Checked;

      objCore.objParametrosDeEntrada.OBSERVACOES                                   := edtObservacoes.Text;
      objCore.objParametrosDeEntrada.DATA_POSTAGEM                                 := FormatDateTime('DD/MM/YYYY', dtpDataPostagem.DateTime);

      if objCore.objParametrosDeEntrada.FAC_REGISTRADO then
        edtDefinirPedido.Text                                                      := objCore.objString.getTermo(2, '_', ListaDeArquivosSelecionados.Strings[0]);

      objCore.objParametrosDeEntrada.PEDIDO_LOTE_MANUAL                          := FormatFloat(objCore.objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToIntDef(edtDefinirPedido.Text, 0));

      objCore.objParametrosDeEntrada.IMPRIMIR                                      := chkImprimir.Checked;

      Executar(); //rrParametrosRetorno                                                       := Executar();

  	  lblNumeroDoLotePedidoValor.Caption                                           := objCore.objParametrosDeEntrada.PEDIDO_LOTE;

      objCore.objParametrosDeEntrada.HORA_FIM_PROCESSO                             := Now;

      LimparSelecao;
      AtualizarArquivosEntrada(edtPathEntrada.Text, true);
      pgcMain.TabIndex := 0;

    finally
      ListaDeArquivosSelecionados.Clear;
      FreeAndNil(ListaDeArquivosSelecionados);

      objCore.objLogar.Logar('[DEBUG] INICIO PROCESSO...: ' + FormatDateTime('DD/MM/YYYY - hh:mm:ss', objCore.objParametrosDeEntrada.HORA_INICIO_PROCESSO));
      objCore.objLogar.Logar('[DEBUG] FIM PROCESSO......: ' + FormatDateTime('DD/MM/YYYY - hh:mm:ss', objCore.objParametrosDeEntrada.HORA_FIM_PROCESSO));
      objCore.objLogar.Logar('[DEBUG] DURACAO PROCESSO..: ' + FormatDateTime('hh:mm:ss', objCore.objParametrosDeEntrada.HORA_FIM_PROCESSO -
                                                                                         objCore.objParametrosDeEntrada.HORA_INICIO_PROCESSO));

      // 0 ----------------------------------------------------0
      // | COPIA O ARQUIVOS DE LOG PARA O DESTINO DOS ARQUIVOS |
      // 0 ----------------------------------------------------0
      CopyFile(objCore.objString.StrToPChar(objCore.objLogar.getArquivoDeLog()),
               objCore.objString.StrToPChar(objCore.objParametrosDeEntrada.PATHSAIDA + ExtractFileName(objCore.objLogar.getArquivoDeLog())), True);

      // 0 ---------------0
      // | ENVIA O E-MAIL |
      // 0 ---------------0
     // objCore.EnviarEmail('FIM DE PROCESSAMENTO !!!', sMSG + #13 + #13 + 'SEGUE LOG EM ANEXO.');

    end;

   // case MessageBox (Application.Handle, Pchar ('FIM DE PROCESSAMENTO !'+#13#10#13#10+'Deseja abrir a pasta de sa�da? '),
   //  'Abrir pasta de sa�da', MB_YESNO) of
   //   idYes:
   //     objCore.objFuncoesWin.ExecutarArquivoComProgramaDefault(objCore.objParametrosDeEntrada.PATHSAIDA);
   // end;

  except

    on E:Exception do
    begin
      sMSG := '[ERRO] Erro ao execultar a Fun��o Executar(). '+#13#10#13#10
             +'EXCE��O: '+ E.Message + #13#10#13#10
             +'O programa ser� encerrado agora.';

      objCore.EnviarEmail('ERRO DE PROCESSAMENTO !!!', sMSG + #13 + #13 + 'SEGUE LOG EM ANEXO.');

      showmessage(sMSG);
      objCore.objLogar.Logar(sMSG);

      Application.Terminate;
    end;
  end;

end;

procedure TfrmMain.FormShow(Sender: TObject);
var
  flLook : TextFile;
  flUser : TextFile;

  stlUser : TStringList;
begin

  TRY

    stlUser := TStringList.Create();

    if FileExists('USER.TXT') then
      stlUser.LoadFromFile('USER.TXT');

    AssignFile(flLook, 'LOOK.TXT');
    Rewrite(flLook);

    AssignFile(flUser, 'USER.TXT');
    Rewrite(flUser);

    Writeln(flUser, GetUsuarioLogado());

    CloseFile(flUser);



          objCore := TCore.Create();

          edtPathEntrada.Text                            := objCore.objParametrosDeEntrada.PATHENTRADA;
          edtPathSaida.Text                              := objCore.objParametrosDeEntrada.PATHSAIDA;
          lblIdProcessamentoValor.Caption                := objCore.objParametrosDeEntrada.ID_PROCESSAMENTO;
          lblNumeroDoLotePedidoValor.Caption             := objCore.objParametrosDeEntrada.PEDIDO_LOTE;
          frmMain.Caption                                := StringReplace(ExtractFileName(Application.ExeName), '.exe', '', [rfReplaceAll, rfIgnoreCase])
                                                            + ' - VERSAO: ' + objCore.objFuncoesWin.GetVersaoDaAplicacao()
                                                            + ' - CONECTADO EM: ' + objCore.objConexao.getHostName();

          edtLote.Clear;
          mmoRelatorio.Clear;
          edtSalvarRelatorio.Clear;

          tbsSaida.TabVisible     := False;
          tsRelatorios.TabVisible := False;

          dtpDataPostagem.DateTime := Now();

          Application.Title := StringReplace(ExtractFileName(Application.ExeName), '.exe', '', [rfReplaceAll, rfIgnoreCase]);

          pgcMain.TabIndex  := 0;
          AtualizarQtdeArquivosMarcados();

          pnl_Numero_de_lotes.Caption:= '';
          pnl_Numero_de_objetos.Caption:= '';
          pnl_Peso_total.Caption:= '';

          edtDefinirPedido.Text := '0';



  except
      on E:Exception do
      begin

        showmessage('ATEN��O, PROGRAMA J� SE ENCONTRA ABERTO.'
                   + #13 + #13 + #13
                   + 'USU�RIO: ' + stlUser.Text
                   +#13#10#13#10
                   //+'EXCE��O: '+E.Message+#13#10#13#10
                   +'O programa ser� encerrado agora.');
        Application.Terminate;
      end;
  end;


end;


procedure TfrmMain.AtualizarArquivosEntrada(path: String; focoAutomatico: boolean=false);
var
  sltListaDeArquivos: TStringList;
begin
  try
    try
      sltListaDeArquivos:= TStringList.Create();
      if Path <> '' then
      begin
        sPathEntrada:=  objCore.objString.AjustaPath(Path);
        //objCore.objFuncoesWin.ObterListaDeArquivosDeUmDiretorio(Path, sltListaDeArquivos);
        objCore.objFuncoesWin.ObterListaDeArquivosDeUmDiretorioV2(Path, sltListaDeArquivos, objCore.objParametrosDeEntrada.EXTENCAO_ARQUIVO);
      end;
      cltArquivos.Items:= sltListaDeArquivos;
    except
      on E:Exception do
      begin

        showmessage('N�o foi poss�vel ler os arquivos no diret�rio ' + Path + '. '+#13#10#13#10
                   +'EXCE��O: '+E.Message+#13#10#13#10
                   +'O programa ser� encerrado agora.');
        Application.Terminate;
      end;
    end;
  finally
    FreeAndNil(sltListaDeArquivos);
  end;
end;

procedure TfrmMain.AtualizarListagemDeArquivos(path: String);
var
  rListaDeObjetosDoDiretorio: RInfoArquivo;
  sNomeArquivo: string;
  sTipoItemLista: string;
  i: integer;
begin

  sPathEntrada := path;

  if copy(sPathEntrada, length(sPathEntrada), 1)<>'\' then
    sPathEntrada := sPathEntrada + '\';

  //Limpa a lista de arquivos:
  cltArquivos.Items.Clear;

  rListaDeObjetosDoDiretorio := objCore.objFuncoesWin.GetArquivos('*.*', sPathEntrada);

  for i:=0 to length(rListaDeObjetosDoDiretorio.Nome) - 1 do
  begin

    sNomeArquivo := rListaDeObjetosDoDiretorio.Nome[i];

    sTipoItemLista := objCore.objFuncoesWin.GetItemArquivoOuDiretorio(sPathEntrada+sNomeArquivo);

    if sTipoItemLista = 'arquivo' then
      cltArquivos.Items.Add(sNomeArquivo);
  end;

end;

procedure TfrmMain.btnSelecionarTodosClick(Sender: TObject);
begin
  SelecionarTodos();
end;

procedure TfrmMain.btnLimparSelecaoClick(Sender: TObject);
begin
  LimparSelecao();
end;

procedure TfrmMain.LimparSelecao();
var
  i: integer;
begin
  {Itera pela CheckListBox e marca cada item (checked = true)}

  for i:=0 to cltArquivos.Items.Count-1 do
  begin
    if cltArquivos.Checked[i] then
      cltArquivos.Checked[i] := false;
  end;

  AtualizarQtdeArquivosMarcados();
end;

procedure TfrmMain.SelecionarTodos();
var
  i: integer;
begin
 {Itera pela CheckListBox e marca cada item (checked = true)}

  for i:=0 to cltArquivos.Items.Count-1 do
    cltArquivos.Checked[i] := true;

  AtualizarQtdeArquivosMarcados();

end;

procedure TfrmMain.DesmarcaAnteriores();
var
  j : Integer;
  iMarcado : Integer;
begin

  iMarcado := cltArquivos.ItemIndex;

  {Itera na checklistbox}
  for j:=0 to cltArquivos.Items.Count-1 do
  begin
    if cltArquivos.Checked[j] then
    begin

      if j <> iMarcado then
        cltArquivos.Checked[j] := False;

    end;
  end;


end;

procedure TfrmMain.AtualizarQtdeArquivosMarcados();
var
  j, iTotalMarcados: integer;
  sNomeArquivoAtual: string;
  rrTamanhoArquivos: RFile;
  iTamArquivos:int64;
begin
  iTotalMarcados := 0;
  iTamArquivos := 0;

  {Itera na checklistbox}
  for j:=0 to cltArquivos.Items.Count-1 do
  begin
    if cltArquivos.Checked[j] then
    begin
      iTotalMarcados    := iTotalMarcados + 1;
      sNomeArquivoAtual := sPathEntrada+cltArquivos.Items[j];

      if trim(sNomeArquivoAtual) <> '' then
        iTamArquivos := iTamArquivos + objCore.objFuncoesWin.GetTamanhoArquivo_WinAPI(sNomeArquivoAtual)
      else
        iTamArquivos := iTamArquivos + 0;
    end;
  end;

//  rrTamanhoArquivos := objCore.objFuncoesWin.GetTamanhoMaiorUnidade(iTamArquivos);

//  lblInfos.Caption := inttostr(iTotalMarcados) + ' arquivo(s) marcado(s)  - '
//   +floattostr(rrTamanhoArquivos.Tamanho) + ' ' + rrTamanhoArquivos.Unidade;

  lblInfos.Caption := inttostr(iTotalMarcados) + ' arquivo(s) marcado(s)  - '
   + objCore.objFuncoesWin.GetTamanhoMaiorUnidade(iTamArquivos);

  lblInfos.Refresh;
  Application.ProcessMessages;

end;

procedure TfrmMain.cltArquivosClick(Sender: TObject);
begin

  if chkFacRegistrado.Checked then
    DesmarcaAnteriores();

  AtualizarQtdeArquivosMarcados();
  
end;

procedure TfrmMain.AboutApplication(autores: String);
var
  sMensagem: string;
  wDia : Word;
  wMes : Word;
  wAno : Word;
begin
  (*

   CRIADA POR: Eduardo Cordeiro M. Monteiro

  *)

  DecodeDate(Now(), wAno, wMes, wDia);

  sMensagem := Application.Title + #13#10
             + ' Vers�o '+ objCore.objFuncoesWin.GetVersaoDaAplicacao() + #13#10
             + ' @2010-' + IntToStr(wAno) + ' Fingerprint - ' + autores;

  showmessage(sMensagem);

end;

function TfrmMain.AplicacaoEstaAberta(NomeAPP: PChar): Boolean;
var
//n�o esque�a de declarar Windows esta uses
Hwnd : THandle;
begin

  Hwnd := FindWindow('TApplication', NomeAPP); //lembrando que Teste � o titulo da sua aplica��o

  // se o Handle e' 0 significa que nao encontrou
  if Hwnd = 0 then
  begin
    // N�o
    Result := False;
  end
  else
  Begin
    // Sim
    Result := True;
    SetForegroundWindow(Hwnd);
  end;

end;



procedure TfrmMain.FormCreate(Sender: TObject);
begin

  if AplicacaoEstaAberta(StrToPChar(StringReplace(ExtractFileName(Application.ExeName), '.exe', '', [rfReplaceAll, rfIgnoreCase])) ) then
  BEGIN
    bAppEstaAberto := True
  end
  else
  begin
    bAppEstaAberto := False;
  end;


end;

function TfrmMain.StrToPChar(const Str: string): PChar;
{Converte String em Pchar}
type
  TRingIndex = 0..7;
var
  Ring: array[TRingIndex] of PChar;
  RingIndex: TRingIndex;
  Ptr: PChar;
begin
  Ptr := @Str[length(Str)];
  Inc(Ptr);
  if Ptr^ = #0 then
  begin
  Result := @Str[1];
  end
  else
  begin
  Result := StrAlloc(length(Str)+1);
  RingIndex := (RingIndex + 1) mod (High(TRingIndex) + 1);
  StrPCopy(Result,Str);
  StrDispose(Ring[RingIndex]);
  Ring[RingIndex]:= Result;
  end;
end;

procedure TfrmMain.btnPesquisarClick(Sender: TObject);
var
  bResultado : Boolean;
begin
  bResultado := objCore.PesquisarLote(edtLote.Text, rgTipoLote.ItemIndex);
  mmoRelatorio.Clear;

  if bResultado then
    mmoRelatorio.Text := objCore.objParametrosDeEntrada.stlRelatorioQTDE.Text
  else
    ShowMessage('N�O ENCONTRATO LOTES PARA A PESQUISA.');

  edtLote.SetFocus;
end;

procedure TfrmMain.btnSalvarRelatorioClick(Sender: TObject);
var
  sArquivo : string;
begin

  if not DirectoryExists(objCore.objString.AjustaPath(edtSalvarRelatorio.Text)) then
    ForceDirectories(objCore.objString.AjustaPath(edtSalvarRelatorio.Text));

  sArquivo := 'RELATORIO_OPERADORAS_LOTE_' + FormatFloat(objCore.objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, strtoint(objCore.objParametrosDeEntrada.PEDIDO_LOTE_TMP)) + '.TXT';
  sArquivo := objCore.objString.AjustaPath(edtSalvarRelatorio.Text) + sArquivo;

  mmoRelatorio.Lines.SaveToFile(sArquivo);

  ShowMessage('RELAT�RIO SALVO EM :' + sArquivo);
  objCore.objFuncoesWin.ExecutarArquivoComProgramaDefault(sArquivo);

  edtLote.Clear;
  mmoRelatorio.Clear;
  edtSalvarRelatorio.Clear;
end;

procedure TfrmMain.edtPathEntradaChange(Sender: TObject);
begin
  LimparSelecao;
  AtualizarArquivosEntrada(edtPathEntrada.Text, true);
end;

function TfrmMain.getUsuarioLogado(): String;
Var
  User : DWord;
begin
  User := 50;
  SetLength(Result, User);
  GetUserName(PChar(Result), User);
  SetLength(Result, StrLen(PChar(Result)));
end;

procedure TfrmMain.btnConfereQuantidadesClick(Sender: TObject);
var
  iContLotes                  : Integer;
  iContObjetos                : Integer;
  iPesoTotal                  : Integer;
  iContArquivosSelecionados   : Integer;
  ListaDeArquivosSelecionados : TStringList;
begin
  btnExecutar.Enabled           := false;
  btnConfereQuantidades.Enabled := false;
  screen.Cursor                 := crSQLWait;

  objCore.objParametrosDeEntrada.PathEntrada                                   := edtPathEntrada.Text;
  objCore.objParametrosDeEntrada.PathSaida                                     := edtPathSaida.Text;

  if objCore.objParametrosDeEntrada.PathEntrada = '' then
    objCore.objParametrosDeEntrada.PathEntrada := '.\';

  objCore.objParametrosDeEntrada.PathEntrada := objCore.objString.AjustaPath(objCore.objParametrosDeEntrada.PathEntrada);

  ListaDeArquivosSelecionados:= TStringList.Create();
  ListaDeArquivosSelecionados.Clear;
  for iContArquivosSelecionados:= 0 to cltArquivos.Count - 1 do
    if cltArquivos.Checked[iContArquivosSelecionados] then
      ListaDeArquivosSelecionados.Add(cltArquivos.Items[iContArquivosSelecionados]);

  objCore.objParametrosDeEntrada.ListaDeArquivosDeEntrada := ListaDeArquivosSelecionados;

  iContLotes   :=0;
  iContObjetos :=0;
  iPesoTotal   :=0;

  ConfereQuantidades(iContLotes, iContObjetos, iPesoTotal);

  pnl_Numero_de_lotes.Caption   := 'Total Lotes....: ' + FormatFloat('000000000000', iContLotes);
  pnl_Numero_de_objetos.Caption := 'Total Objetos..: ' + FormatFloat('000000000000', iContObjetos);
  pnl_Peso_total.Caption        := 'Peso Total.....: ' + FormatFloat('000000000000', iPesoTotal);

  btnExecutar.Enabled           := true;
  btnConfereQuantidades.Enabled := True;
  screen.Cursor                 := crDefault;
end;

procedure TfrmMain.ConfereQuantidades(Var iNumeroDeLotes, iNumeroDeObjetos, iPeso: Integer);
var
  txtEntrada                     : TextFile;
  i                              : Integer;
  iContArquivos                  : Integer;
  sNome_do_zip                   : string;
  sDestino_dos_arquivos_temp_zip : string;
  sArquivo                       : string;
  sLote                          : string;
  sLinha                         : string;
  sTipo                          : string;

begin

//  iNumeroDeLotes   := 0;
//  iNumeroDeObjetos := 0;
//  iPeso            := 0;


  For iContArquivos := 0 to objCore.objParametrosDeEntrada.ListaDeArquivosDeEntrada.Count - 1 do
  Begin

       sArquivo := objCore.objParametrosDeEntrada.ListaDeArquivosDeEntrada.Strings[iContArquivos];

       AssignFile(txtEntrada, objCore.objParametrosDeEntrada.PathEntrada + sArquivo);
       Reset(txtEntrada);

       While Not Eof(txtEntrada) do
       Begin
         readln(txtEntrada, sLinha);
         sTipo := copy(sLinha, 1, 1);
         if sTipo = '2' then
         Begin
           iNumeroDeObjetos := iNumeroDeObjetos + 1;
           iPeso            := iPeso + StrToInt(copy(sLinha, 13, 6));
         End;
       end;
       closefile(txtEntrada);

       iNumeroDeLotes := iNumeroDeLotes + 1;

  end;

end;

procedure TfrmMain.chkFacRegistradoClick(Sender: TObject);
begin
  LimparSelecao();
  if chkFacRegistrado.Checked then
  begin
    edtDefinirPedido.Text := '00000';
    edtDefinirPedido.Enabled := False;
    btnConfereQuantidades.Enabled := False;
  end
  else
  begin
    edtDefinirPedido.Enabled := True;
    btnConfereQuantidades.Enabled := True;
  end;
end;

procedure TfrmMain.pgcMainChange(Sender: TObject);
var
  ListaDeArquivosSelecionados : TStrings;
  iContArquivosSelecionados   : Integer;
  sMSG                        : STRING;

begin

  ListaDeArquivosSelecionados := TStrings.Create();

  ListaDeArquivosSelecionados:= TStringList.Create();
  for iContArquivosSelecionados:= 0 to cltArquivos.Count - 1 do
    if cltArquivos.Checked[iContArquivosSelecionados] then
      ListaDeArquivosSelecionados.Add(cltArquivos.Items[iContArquivosSelecionados]);

  if pgcMain.TabIndex <> 0 then
  Begin

    if (pgcMain.TabIndex = 1) then
    begin

      if ListaDeArquivosSelecionados.Count = 0 then
      begin
        sMSG := #13 + 'Voc� est� tentando ir em EXECUTAR com ' + IntToStr(ListaDeArquivosSelecionados.Count) + ' arquivos selecionados.';
        objCore.objLogar.Logar(sMSG);
        ShowMessage(sMSG);
        pgcMain.TabIndex  := 0;
      end
      else
      if pgcMain.TabIndex = 2 then
      begin

        sMSG := #13 + 'CONFIRMA��O !'+#13#10#13#10+ IntToStr(ListaDeArquivosSelecionados.Count) + ' arquivo selecionados.' + #13 + 'Deseja continuar?';
        objCore.objLogar.Logar(sMSG);

        case MessageBox (Application.Handle, Pchar (sMSG),
         'Deseja continuar ?', MB_YESNO) of
          IDYES: Begin
                   objCore.objLogar.Logar('SIM.');
                 end;

          IDNO : Begin
                   objCore.objLogar.Logar('N�O.');
                   pgcMain.TabIndex  := 0;
                 end;
        end;

      end;
    end;

  end;
end;

end.


